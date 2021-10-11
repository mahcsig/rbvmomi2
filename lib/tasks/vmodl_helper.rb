# frozen_string_literal: true
require 'active_support/core_ext/enumerable'
require 'active_support/inflector'
require 'optimist'
require 'pathname'
require 'wsdl/parser'
require 'rbvmomi'
require 'rbvmomi/pbm'
require 'rbvmomi/sms'

class VmodlHelper
  class << self
    def verify!(argv)
      opts = Optimist.options(argv) do
        educate_on_error
        opt :wsdl, 'Path to the vsphere-ws wsdl file', type: :string, required: true
        opt :vmodl, 'Path to the vmodl.db', type: :string, default: 'vmodl.db'
        banner <<~EOS
          Usage:
          rake vmodl:verify -- --wsdl=path/to/wsdl
        EOS
      end

      new(vmodl_path: opts[:vmodl], wsdl_path: opts[:wsdl]).verify!
    end

    def generate!(argv)
      opts = Optimist.options(argv) do
        educate_on_error
        opt :wsdl, 'Path to the vsphere-ws wsdl file', type: :string, required: true
        opt :vmodl, 'Path to the vmodl.db', type: :string, default: 'vmodl.db'
        banner <<~EOS
          Usage:
          rake vmodl:generate -- --wsdl=path/to/wsdl
        EOS
      end

      new(vmodl_path: opts[:vmodl], wsdl_path: opts[:wsdl]).generate!
    end
  end

  def initialize(vmodl_path:, wsdl_path:)
    @vmodl_path = Pathname.new(vmodl_path)
    @wsdl_path  = Pathname.new(wsdl_path)

    @vmodl = load_vmodl(@vmodl_path)
    @wsdl  = load_wsdl(@wsdl_path)
  end

  def verify!
    # Loop through the ComplexTypes in the WSDL and compare their types
    # to the types which are defined in the vmodl.db
    wsdl_types_by_name.each_value do |type|
      type_name = type.name.name
      next if type_name.match?(/^ArrayOf/) || type_name.match(/RequestType$/)

      vmodl_data = @vmodl[type_name]

      # If a type exists in the WSDL but not in the vmodl.db this usually
      # indicates that it was added in a newer version than the current
      # vmodl.db supports.
      #
      # Print a warning that the type is missing and skip it.
      if vmodl_data.nil?
        puts " #{type_name} is missing"
        next
      end

      # Index the properties by name to make it simpler to find later
      elements_by_name = type.elements.index_by { |e| e.name.name }

      # Loop through the properties defined in the vmodl.db for this type and
      # compare the type to that property as defined in the wsdl.
      vmodl_data['props'].each do |vmodl_prop|
        wsdl_prop = elements_by_name[vmodl_prop['name']]
        next if wsdl_prop.nil?

        vmodl_klass = wsdl_constantize(vmodl_prop['wsdl_type'])
        wsdl_klass  = wsdl_constantize(wsdl_prop.type.source)

        # The vmodl class should be equal to or a subclass of the one in the wsdl.
        # Example of a subclass is e.g. VirtualMachine.host is defined as a HostSystem
        # in the vmodl.db but it is a ManagedObjectReference in the wsdl.
        puts "#{type_name}.#{vmodl_prop["name"]} #{wsdl_klass.wsdl_name} doesn't match #{vmodl_klass.wsdl_name}" unless vmodl_klass <= wsdl_klass
      end
    end
  end

  def generate!
    wsdl_types_by_name.each_value do |type|
      type_name  = type.name.name
      vmodl_data = @vmodl[type_name]

      if vmodl_data.nil?
        base_class           = wsdl_types_by_name[type.complexcontent.extension.base.name]
        inherited_properties = base_class.elements.map { |element| element.name.name }
        properties           = type.elements.reject { |e| inherited_properties.include?(e.name.name) }

        vmodl_data = {
          'kind'      => 'data',
          'props'     => properties.map do |element|
            {
              'name'           => element.name.name,
              'is-optional'    => element.minoccurs == 0,
              'is-array'       => element.maxoccurs != 1,
              'version-id-ref' => nil,
              'wsdl_type'      => wsdl_to_vmodl_type(element.type)
            }
          end,
          'wsdl_base' => type.complexcontent.extension.base.name
        }

        @vmodl[type_name] = vmodl_data
        @vmodl['_typenames']['_typenames'] << type_name

        puts "Adding #{type_name} to vmodl"

        wsdl_to_rbvmomi_namespace(type).loader.add_types type_name => vmodl_data
      end
    end

    wsdl_types_by_name.each_value do |type|
      type_name = type.name.name
      vmodl_data = @vmodl[type_name]

      elements_by_name = type.elements.index_by { |e| e.name.name }

      # Loop through the properties defined in the vmodl.db for this type and
      # compare the type to that property as defined in the wsdl.
      vmodl_data['props'].each do |vmodl_prop|
        wsdl_prop = elements_by_name[vmodl_prop['name']]
        next if wsdl_prop.nil?

        vmodl_klass = wsdl_constantize(vmodl_prop['wsdl_type'])
        wsdl_klass  = wsdl_constantize(wsdl_prop.type.source)

        vmodl_prop['wsdl_type'] = wsdl_klass.wsdl_name unless vmodl_klass <= wsdl_klass
      end
    end

    dump_vmodl!
  end

  protected

  def load_wsdl(path)
    # WSDL includes have to resolve in the local directory so we have to
    # change working directories to where the wsdl is
    Dir.chdir(path.dirname) do
      WSDL::Parser.new.parse(path.read)
    end
  end

  def load_vmodl(path)
    Marshal.load(path.read)
  end

  def dump_vmodl!
    File.write(@vmodl_path, Marshal.dump(@vmodl))
  end

  private

  def wsdl_types_by_name
    @wsdl_types_by_name ||= @wsdl.collect_complextypes
      .reject   { |type| type.name.name.match?(/^ArrayOf|RequestType$/) }
      .index_by { |type| type.name.name }
  end

  def wsdl_to_vmodl_type(type)
    case type.source
    when /vim25:/, /pbm:/, /sms:/
      vmodl_type = type.name == 'ManagedObjectReference' ? 'ManagedObject' : type.name
    when /xsd:/
      vmodl_type = type.source
    else
      raise ArgumentError, "Unrecognized wsdl type: [#{type}]"
    end

    vmodl_type
  end

  def wsdl_to_rbvmomi_namespace(type)
    case type.targetnamespace
    when 'urb:vim25'
      RbVmomi::VIM
    when 'urn:pbm'
      RbVmomi::PBM
    when 'urn:sms'
      RbVmomi::SMS
    else
      raise ArgumentError, "Unrecognized namespace [#{type}]"
    end
  end

  # Normalize the type, some of these don't have RbVmomi equivalents such as xsd:long
  # and RbVmomi uses ManagedObjects not ManagedObjectReferences as parameters
  def wsdl_constantize(type)
    type = type.split(':').last
    type = 'int'           if %w[long short byte].include?(type)
    type = 'float'         if type == 'double'
    type = 'binary'        if type == 'base64Binary'
    type = 'ManagedObject' if type == 'ManagedObjectReference'

    type = type.camelcase
    type.safe_constantize || "RbVmomi::BasicTypes::#{type}".safe_constantize || "RbVmomi::VIM::#{type}".safe_constantize
  end
end
