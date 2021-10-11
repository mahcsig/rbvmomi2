# frozen_string_literal: true

require_relative './vmodl_helper'

namespace :vmodl do
  desc 'Verify vmodl.db'
  task :verify do
    VmodlHelper.verify!(argv)
  end

  task :generate do
    VmodlHelper.generate!(argv)
  end

  private

  # Pass everything after the `--` to Optimist
  # E.g. rake vmodl:verify -- --wsdl=path/to/wsdl
  def argv
    (i = ARGV.index('--')) ? ARGV.slice((i + 1)..-1) : ARGV.dup
  end
end
