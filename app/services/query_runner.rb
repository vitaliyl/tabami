# frozen_string_literal: true

require "json"
require "bigdecimal"
require "time"
require "dry/monads"
require_relative "../structs"

module Tabami
  module Services
    class QueryRunner
      extend Dry::Monads[:result]

      DEFAULT_LIMIT = 500

      def self.execute_monad(db, sql, limit: DEFAULT_LIMIT, adapter: nil)
        result = execute(db, sql, limit: limit, adapter: adapter)
        if result[:success]
          Success(Structs::QueryResult.new(result))
        else
          Failure(result)
        end
      end

      def self.execute(db, sql, limit: DEFAULT_LIMIT, adapter: nil)
        clean_sql = sql.to_s.strip.sub(/;+\z/, "").strip
        return { success: false, error: "SQL query cannot be empty" } if clean_sql.empty?

        is_select = clean_sql.match?(/\A\s*(SELECT|WITH|SHOW|PRAGMA|DESCRIBE)/i)
        can_limit = clean_sql.match?(/\A\s*(SELECT|WITH)\b/i)
        duration_ms = 0
        columns = []
        rows = []
        rows_affected = nil

        begin
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          if is_select
            dataset = db.fetch(clean_sql)
            raw_rows = if !can_limit || clean_sql.match?(/\bLIMIT\s+\d+/i)
                         dataset.all
                       else
                         dataset.limit(limit).all
                       end

            if raw_rows.any?
              columns = raw_rows.first.keys.map(&:to_s)
              rows = raw_rows.map do |row|
                row.transform_keys(&:to_s).transform_values { |v| format_value(v) }
              end
            elsif dataset.columns.any?
              columns = dataset.columns.map(&:to_s)
            end
          else
            rows_affected = db.run(clean_sql)
          end
          end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          duration_ms = ((end_time - start_time) * 1000).round(2)

          {
            success: true,
            is_select: is_select,
            columns: columns,
            rows: rows,
            row_count: rows.size,
            rows_affected: rows_affected,
            duration_ms: duration_ms,
            sql: clean_sql
          }
        rescue Sequel::DatabaseError => e
          {
            success: false,
            error: e.message,
            sql: clean_sql
          }
        rescue StandardError => e
          {
            success: false,
            error: "Execution error: #{e.message}",
            sql: clean_sql
          }
        end
      end

      def self.format_value(value)
        case value
        when nil
          nil
        when Time, DateTime, Date
          value.iso8601
        when BigDecimal
          value.to_s("F")
        when Hash, Array
          value
        when String
          value.valid_encoding? ? value : "[Binary data #{value.bytesize} bytes]"
        when Sequel::SQL::Blob
          "[Blob #{value.bytesize} bytes]"
        else
          if defined?(Sequel::Postgres::PGArray) && value.is_a?(Sequel::Postgres::PGArray)
            value.to_a
          elsif defined?(Sequel::SQL::QualifiedIdentifier) && value.is_a?(Sequel::SQL::QualifiedIdentifier)
            value.column.to_s
          elsif defined?(Sequel::SQL::Identifier) && value.is_a?(Sequel::SQL::Identifier)
            value.value.to_s
          else
            value
          end
        end
      end
    end
  end
end
