# frozen_string_literal: true

module RbVmomi
  class << self
    attr_writer :logger
  end

  def self.logger
    require 'logger'
    @logger ||= Logger.new(nil)
  end

  module Logging
    def logger
      RbVmomi.logger
    end
  end
end
