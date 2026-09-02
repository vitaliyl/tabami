# frozen_string_literal: true

require "dry/cli"
require "json"
require_relative "../config"

module Tabami
  module CLI
    module Commands
      extend Dry::CLI::Registry

      class Version < Dry::CLI::Command
        desc "Print Tabami version"

        def call(*)
          puts "Tabami v#{Tabami.config.app_version}"
        end
      end

      class Server < Dry::CLI::Command
        desc "Start Tabami Puma Web Application Server"

        option :port, type: :integer, default: 2300, desc: "Server port"
        option :open, type: :boolean, default: false, desc: "Open browser on boot"

        def call(port: 2300, open: false, **)
          puts "🚀 Starting Tabami Studio on http://localhost:#{port} ..."
          if open
            Thread.new do
              sleep 1.2
              system("open http://localhost:#{port} || xdg-open http://localhost:#{port} 2>/dev/null")
            end
          end
          exec("bundle exec hanami server --port #{port}")
        end
      end

      register "version", Version, aliases: ["v", "-v", "--version"]
      register "server", Server, aliases: ["start", "s"]
    end
  end
end
