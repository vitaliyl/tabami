# frozen_string_literal: true

module Tabami
  module Services
    class SchemaInspector
      def self.extract_identifier_name(ident)
        return "" if ident.nil?

        if defined?(Sequel::SQL::QualifiedIdentifier) && ident.is_a?(Sequel::SQL::QualifiedIdentifier)
          extract_identifier_name(ident.column)
        elsif defined?(Sequel::SQL::Identifier) && ident.is_a?(Sequel::SQL::Identifier)
          extract_identifier_name(ident.value)
        elsif ident.is_a?(Symbol) || ident.is_a?(String)
          ident.to_s
        elsif ident.respond_to?(:column)
          extract_identifier_name(ident.column)
        elsif ident.respond_to?(:value)
          extract_identifier_name(ident.value)
        else
          ident.to_s
        end
      end

      def self.extract_identifier_schema(ident)
        return nil if ident.nil?

        if defined?(Sequel::SQL::QualifiedIdentifier) && ident.is_a?(Sequel::SQL::QualifiedIdentifier)
          extract_identifier_name(ident.table)
        elsif ident.respond_to?(:table)
          extract_identifier_name(ident.table)
        else
          nil
        end
      end

      def self.inspect_schemas(db, adapter)
        case adapter.to_s.downcase
        when "postgres", "postgresql"
          begin
            rows = db.fetch("SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('pg_toast', 'pg_temp_1', 'pg_toast_temp_1') ORDER BY (schema_name = 'public') DESC, schema_name ASC").all
            schemas = rows.map { |r| (r[:schema_name] || r.values.first).to_s }
            schemas.any? ? schemas : ["public"]
          rescue StandardError
            ["public"]
          end
        when "sqlite"
          ["main"]
        when "mysql", "mysql2"
          begin
            db.fetch("SHOW SCHEMAS").map { |r| r.values.first.to_s }.sort
          rescue StandardError
            ["default"]
          end
        else
          ["public"]
        end
      rescue StandardError
        ["public"]
      end

      def self.inspect_tables(db, adapter, schema = nil)
        tables = []

        case adapter.to_s.downcase
        when "postgres", "postgresql"
          target_schema = (schema.to_s.strip.empty? || schema == "default") ? "public" : schema.to_s.strip

          begin
            sql = <<~SQL
              SELECT 
                c.relname AS table_name,
                CASE c.relkind 
                  WHEN 'r' THEN 'table'
                  WHEN 'v' THEN 'view'
                  WHEN 'm' THEN 'view'
                  WHEN 'f' THEN 'table'
                  WHEN 'p' THEN 'table'
                  ELSE 'table'
                END AS table_type,
                n.nspname AS table_schema,
                c.reltuples::bigint AS estimated_rows
              FROM pg_catalog.pg_class c
              JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
              WHERE n.nspname = ?
                AND c.relkind IN ('r', 'v', 'm', 'f', 'p')
              ORDER BY c.relname;
            SQL

            rows = db.fetch(sql, target_schema).all
            if rows.any?
              tables = rows.map do |r|
                est = r[:estimated_rows]
                tuples = est && est.to_i >= 0 ? est.to_i : nil
                {
                  name: r[:table_name].to_s,
                  type: r[:table_type].to_s.include?("view") ? "view" : "table",
                  schema: target_schema,
                  estimated_rows: tuples
                }
              end
            else
              info_sql = "SELECT table_name, table_type FROM information_schema.tables WHERE table_schema = ? ORDER BY table_name"
              tables = db.fetch(info_sql, target_schema).map do |r|
                is_view = r[:table_type].to_s.include?("VIEW")
                {
                  name: r[:table_name].to_s,
                  type: is_view ? "view" : "table",
                  schema: target_schema,
                  estimated_rows: nil
                }
              end
            end
          rescue StandardError
            begin
              info_sql = "SELECT table_name, table_type FROM information_schema.tables WHERE table_schema = ? ORDER BY table_name"
              tables = db.fetch(info_sql, target_schema).map do |r|
                is_view = r[:table_type].to_s.include?("VIEW")
                {
                  name: r[:table_name].to_s,
                  type: is_view ? "view" : "table",
                  schema: target_schema,
                  estimated_rows: nil
                }
              end
            rescue StandardError
              tables = []
            end
          end

        when "sqlite"
          table_names = db.tables.map { |t| extract_identifier_name(t) }.sort
          view_names = db.views.map { |v| extract_identifier_name(v) }.sort

          tables = table_names.map do |t_name|
            count = begin
              db[t_name.to_sym].count
            rescue StandardError
              0
            end
            {
              name: t_name,
              type: "table",
              schema: "main",
              estimated_rows: count
            }
          end

          view_names.each do |v_name|
            tables << {
              name: v_name,
              type: "view",
              schema: "main",
              estimated_rows: nil
            }
          end

        when "mysql", "mysql2"
          db_tables = db.tables.map { |t| extract_identifier_name(t) }.sort
          tables = db_tables.map do |t_name|
            count = begin
              db[t_name.to_sym].count
            rescue StandardError
              0
            end
            {
              name: t_name,
              type: "table",
              schema: db.opts[:database] || "default",
              estimated_rows: count
            }
          end
        end

        tables
      rescue StandardError
        []
      end

      def self.inspect_structure(db, adapter, table_name, schema = nil, reload: false)
        table_sym = schema && adapter.to_s.include?("postgres") ? Sequel[schema.to_sym][table_name.to_sym] : table_name.to_sym

        # 1. Columns schema
        raw_schema = begin
          db.schema(table_sym, reload: reload)
        rescue StandardError
          []
        end

        columns = raw_schema.map do |col_name, info|
          {
            name: extract_identifier_name(col_name),
            type: info[:type].to_s,
            db_type: info[:db_type].to_s,
            allow_null: info[:allow_null] || false,
            default: info[:default]&.to_s,
            primary_key: info[:primary_key] || false,
            max_length: info[:max_length],
            numeric_precision: info[:numeric_precision],
            numeric_scale: info[:numeric_scale]
          }
        end

        # 2. Primary Keys
        pk_columns = columns.select { |c| c[:primary_key] }.map { |c| c[:name] }
        if pk_columns.empty?
          begin
            pk_columns = Array(db.primary_key(table_sym)).map { |c| extract_identifier_name(c) }
          rescue StandardError
            # No primary key found
          end
        end

        # 3. Foreign Keys
        foreign_keys = begin
          db.foreign_key_list(table_sym).map do |fk|
            fk_name = extract_identifier_name(fk[:name])
            cols = Array(fk[:columns]).map { |c| extract_identifier_name(c) }
            {
              name: fk_name.empty? ? "fk_#{cols.join('_')}" : fk_name,
              columns: cols,
              table: extract_identifier_name(fk[:table]),
              schema: extract_identifier_schema(fk[:table]),
              key: Array(fk[:key]).map { |k| extract_identifier_name(k) },
              on_delete: fk[:on_delete]&.to_s,
              on_update: fk[:on_update]&.to_s
            }
          end
        rescue StandardError
          []
        end

        # 4. Indexes
        indexes = begin
          db.indexes(table_sym).map do |idx_name, idx_info|
            {
              name: extract_identifier_name(idx_name),
              columns: Array(idx_info[:columns]).map { |c| extract_identifier_name(c) },
              unique: idx_info[:unique] || false
            }
          end
        rescue StandardError
          []
        end

        # 5. Row count
        total_rows = begin
          db[table_sym].count
        rescue StandardError
          0
        end

        {
          table_name: table_name,
          schema: schema || "public",
          columns: columns,
          primary_keys: pk_columns,
          foreign_keys: foreign_keys,
          indexes: indexes,
          total_rows: total_rows
        }
      end
    end
  end
end
