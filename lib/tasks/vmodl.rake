# frozen_string_literal: true

namespace :vmodl do
  desc 'Verify vmodl.db'
  task :verify do
    wsdl_path, vmodl_path = parse_options.values_at(:wsdl, :vmodl)

    `bundle exec ruby devel/verify-vim-wsdl.rb #{wsdl_path} #{vmodl_path}`
  end

  task :generate do
    wsdl_path, vmodl_path = parse_options.values_at(:wsdl, :vmodl)

    `bundle exec ruby devel/verify-vim-wsdl.rb #{wsdl_path} #{vmodl_path} --fix`
  end

  private

  def parse_options
    require 'optimist'

    Optimist.options(argv) do
      educate_on_error
      opt :wsdl, 'Path to the vsphere-ws wsdl file', type: :string, required: true
      opt :vmodl, 'Path to the vmodl.db', type: :string, default: 'vmodl.db'
      banner <<~EOS
        Usage:
        rake vmodl:verify -- --wsdl=path/to/wsdl
      EOS
    end
  end

  # Pass everything after the `--` to Optimist
  # E.g. rake vmodl:verify -- --wsdl=path/to/wsdl
  def argv
    (i = ARGV.index('--')) ? ARGV.slice((i + 1)..-1) : ARGV.dup
  end
end
