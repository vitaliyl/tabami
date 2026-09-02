# frozen_string_literal: true

require "dry-struct"
require_relative "../types"

module Tabami
  module Structs
    class QueryResult < Dry::Struct
      transform_keys(&:to_sym)

      attribute :success, Types::Bool.default(true)
      attribute? :is_select, Types::Bool.optional
      attribute? :columns, Types::Array.of(Types::String).default([].freeze)
      attribute? :rows, Types::Array.of(Types::Hash).default([].freeze)
      attribute? :row_count, Types::Coercible::Integer.default(0)
      attribute? :rows_affected, Types::Coercible::Integer.optional
      attribute? :duration_ms, Types::Coercible::Float.default(0.0)
      attribute? :sql, Types::String.optional
      attribute? :error, Types::String.optional
    end
  end
end
