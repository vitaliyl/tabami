# frozen_string_literal: true

require "dry-configurable"

module Tabami
  class Config
    extend Dry::Configurable

    setting :app_version, default: ENV.fetch("APP_VERSION", "0.1.0")
    setting :default_query_limit, default: 500
    setting :max_query_limit, default: 5000
    setting :connection_timeout, default: 5
  end

  def self.config
    Config.config
  end

  def self.configure(&block)
    Config.configure(&block)
  end
end
