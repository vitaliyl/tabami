# frozen_string_literal: true

require "dry/cli"
require_relative "cli/commands"

module Tabami
  module CLI
    def self.start(args = ARGV)
      Dry::CLI.new(Commands).call(arguments: args)
    end
  end
end
