# frozen_string_literal: true

require_relative './vmodl_helper'

namespace :vmodl do
  desc 'Verify vmodl.db'
  task :verify do
    VmodlHelper.verify!
  end

  task :generate do
    VmodlHelper.generate!
  end
end
