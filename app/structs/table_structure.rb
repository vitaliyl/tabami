# frozen_string_literal: true

require "dry-struct"
require_relative "../types"

module Tabami
  module Structs
    class ColumnDefinition < Dry::Struct
      transform_keys(&:to_sym)

      attribute :name, Types::String
      attribute :type, Types::String
      attribute? :db_type, Types::String.optional
      attribute? :allow_null, Types::Bool.default(false)
      attribute? :default, Types::String.optional
      attribute? :primary_key, Types::Bool.default(false)
      attribute? :max_length, Types::Coercible::Integer.optional
      attribute? :numeric_precision, Types::Coercible::Integer.optional
      attribute? :numeric_scale, Types::Coercible::Integer.optional
    end

    class ForeignKey < Dry::Struct
      transform_keys(&:to_sym)

      attribute :name, Types::String
      attribute :columns, Types::Array.of(Types::String)
      attribute :table, Types::String
      attribute? :schema, Types::String.optional
      attribute :key, Types::Array.of(Types::String)
      attribute? :on_delete, Types::String.optional
      attribute? :on_update, Types::String.optional
    end

    class IndexDefinition < Dry::Struct
      transform_keys(&:to_sym)

      attribute :name, Types::String
      attribute :columns, Types::Array.of(Types::String)
      attribute? :unique, Types::Bool.default(false)
    end

    class TableStructure < Dry::Struct
      transform_keys(&:to_sym)

      attribute :table_name, Types::String
      attribute :schema, Types::String.default("public")
      attribute :columns, Types::Array.of(ColumnDefinition)
      attribute :primary_keys, Types::Array.of(Types::String)
      attribute :foreign_keys, Types::Array.of(ForeignKey)
      attribute :indexes, Types::Array.of(IndexDefinition)
      attribute? :total_rows, Types::Coercible::Integer.default(0)
    end

    class TableSummary < Dry::Struct
      transform_keys(&:to_sym)

      attribute :name, Types::String
      attribute :type, Types::String.default("table") # table, view
      attribute :schema, Types::String.default("public")
      attribute? :estimated_rows, Types::Coercible::Integer.optional
    end
  end
end
