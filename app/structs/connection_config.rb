# frozen_string_literal: true

require "dry-struct"
require_relative "../types"

module Tabami
  module Structs
    class ConnectionConfig < Dry::Struct
      transform_keys(&:to_sym)

      attribute :id, Types::String
      attribute :name, Types::String.default("New Connection")
      attribute :adapter, Types::String.default("postgres") # postgres, sqlite, mysql
      attribute? :host, Types::String.optional.default("localhost")
      attribute? :port, Types::Coercible::Integer.optional.default(5432)
      attribute? :database, Types::String.optional
      attribute? :username, Types::String.optional
      attribute? :password, Types::String.optional
      attribute? :file_path, Types::String.optional
      attribute? :ssl, Types::Bool.default(false)
      attribute? :is_demo, Types::Bool.default(false)
      attribute? :created_at, Types::String.optional

      def sqlite?
        adapter == "sqlite" || adapter == "sqlite3"
      end

      def postgres?
        adapter == "postgres" || adapter == "postgresql"
      end

      def mysql?
        adapter == "mysql" || adapter == "mysql2"
      end
    end
  end
end
