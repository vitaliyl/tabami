# frozen_string_literal: true

require "sequel"
require "json"
require "fileutils"
require "securerandom"
require "dry/monads"
require_relative "../structs"
require_relative "demo_database"

module Tabami
  module Services
    class ConnectionManager
      include Dry::Monads[:result]

      STORAGE_FILE = File.expand_path("../../db/saved_connections.json", __dir__)

      def initialize
        @pools = {}
        ensure_storage!
      end

      def all_connections
        raw = load_storage
        raw.map do |c|
          {
            id: c["id"],
            name: c["name"],
            adapter: c["adapter"], # postgres, sqlite, mysql
            host: c["host"],
            port: c["port"],
            database: c["database"],
            username: c["username"],
            file_path: c["file_path"],
            ssl: c["ssl"],
            is_demo: c["is_demo"] || false,
            created_at: c["created_at"]
          }
        end
      end

      def all_configs
        all_connections.map { |c| Structs::ConnectionConfig.new(c) }
      end

      def find(id)
        all_connections.find { |c| c[:id] == id }
      end

      def find_config(id)
        conn = find(id)
        conn ? Structs::ConnectionConfig.new(conn) : nil
      end

      def create(attrs)
        connections = load_storage
        cfg = Structs::ConnectionConfig.new(
          id: SecureRandom.uuid,
          name: attrs[:name] || attrs["name"] || "New Connection",
          adapter: attrs[:adapter] || attrs["adapter"] || "postgres",
          host: attrs[:host] || attrs["host"] || "localhost",
          port: (attrs[:port] || attrs["port"] || 5432).to_i,
          database: attrs[:database] || attrs["database"],
          username: attrs[:username] || attrs["username"],
          password: attrs[:password] || attrs["password"],
          file_path: attrs[:file_path] || attrs["file_path"],
          ssl: attrs[:ssl] || attrs["ssl"] || false,
          is_demo: false,
          created_at: Time.now.iso8601
        )
        new_conn = cfg.to_h.transform_keys(&:to_s)
        connections << new_conn
        save_storage(connections)
        find(cfg.id)
      end

      def delete(id)
        connections = load_storage
        conn = connections.find { |c| c["id"] == id }
        return false if conn && conn["is_demo"] # Protect demo database

        disconnect(id)
        filtered = connections.reject { |c| c["id"] == id }
        save_storage(filtered)
        true
      end

      def test_connection(config)
        url = build_connection_url(config)
        begin
          db = Sequel.connect(url, connect_timeout: 5, timeout: 5)
          db.test_connection
          server_version = begin
            if config[:adapter].to_s == "sqlite" || config["adapter"].to_s == "sqlite"
              db.get(Sequel.function(:sqlite_version))
            elsif config[:adapter].to_s == "postgres" || config["adapter"].to_s == "postgres"
              db.get(Sequel.function(:version))
            else
              db.get(Sequel.function(:version))
            end
          rescue StandardError
            "Connected"
          end
          db.disconnect
          { success: true, message: "Connection successful!", server_version: server_version.to_s }
        rescue Sequel::DatabaseConnectionError => e
          { success: false, message: "Database connection failed: #{e.message}" }
        rescue StandardError => e
          { success: false, message: "Error: #{e.message}" }
        end
      end

      def discover_databases(config)
        cfg = config.respond_to?(:to_h) ? config.to_h : (config || {})
        normalized = {}
        cfg.each { |k, v| normalized[k.to_s] = v }
        adapter = (normalized["adapter"] || "postgres").to_s.downcase

        case adapter
        when "postgres", "postgresql"
          # 1. Try direct PgBouncer admin virtual DB probe first
          begin
            require "pg"
            pg_host = normalized["host"] || "localhost"
            pg_host = "localhost" if pg_host.to_s.strip.empty?
            pg_port = (normalized["port"] || 5432).to_i
            pg_port = 5432 if pg_port <= 0
            pg_user = normalized["username"]
            pg_pass = normalized["password"]

            pg_conn = PG.connect(
              host: pg_host,
              port: pg_port,
              dbname: "pgbouncer",
              user: pg_user.to_s.empty? ? "postgres" : pg_user,
              password: pg_pass.to_s.empty? ? nil : pg_pass,
              connect_timeout: 3
            )
            res = pg_conn.exec("SHOW DATABASES")
            names = []
            res.each do |row|
              name = row["name"] || row["database"]
              names << name.to_s if name && name != "pgbouncer" && !name.empty?
            end
            pg_conn.close
            names = names.uniq.sort
            if names.any?
              return {
                success: true,
                databases: names,
                is_pgbouncer: true,
                message: "Discovered #{names.length} pool database(s) from PgBouncer"
              }
            end
          rescue StandardError
            # Not accessible via virtual pgbouncer db
          end

          target_user = normalized["username"].to_s
          given_db = normalized["database"].to_s.strip
          candidates = [given_db, "postgres", "template1", target_user].compact.map(&:to_s).reject(&:empty?).uniq
          candidates = ["postgres", "template1"] if candidates.empty?

          last_error = nil

          candidates.each do |probe_db|
            test_cfg = normalized.merge("database" => probe_db)
            url = build_connection_url(test_cfg)
            begin
              db = Sequel.connect(url, connect_timeout: 4, timeout: 4)

              # 2. Try PostgreSQL standard catalog query
              begin
                rows = db.fetch("SELECT datname FROM pg_database WHERE datistemplate = false AND datallowconn = true ORDER BY datname").all
                if rows.any?
                  names = rows.map { |r| r[:datname].to_s }.reject(&:empty?).uniq.sort
                  db.disconnect
                  return {
                    success: true,
                    databases: names,
                    is_pgbouncer: false,
                    message: "Discovered #{names.length} database(s) on PostgreSQL server"
                  }
                end
              rescue StandardError
                # Query failed on this connection
              end

              db.disconnect
            rescue Sequel::DatabaseConnectionError => e
              last_error = e.message
            rescue StandardError => e
              last_error = e.message
            end
          end

          err_msg = if normalized["port"].to_i == 6432 || (last_error && last_error.include?("no such database"))
                      "Discovery failed: #{last_error}. If connecting via PgBouncer or connection pooler, please enter your database name directly."
                    else
                      "Discovery failed: #{last_error || 'No accessible databases or pools found on this host/port'}"
                    end

          { success: false, message: err_msg }

        when "mysql", "mysql2"
          test_cfg = normalized.merge("database" => nil)
          url = build_connection_url(test_cfg)
          begin
            db = Sequel.connect(url, connect_timeout: 4, timeout: 4)
            rows = db.fetch("SHOW DATABASES").all
            system_dbs = %w[information_schema performance_schema mysql sys]
            names = rows.map { |r| r.values.first.to_s }.reject { |n| system_dbs.include?(n.downcase) || n.empty? }.uniq.sort
            db.disconnect
            { success: true, databases: names, is_pgbouncer: false, message: "Discovered #{names.length} MySQL database(s)" }
          rescue Sequel::DatabaseConnectionError => e
            { success: false, message: "Database discovery failed: #{e.message}" }
          rescue StandardError => e
            { success: false, message: "Error: #{e.message}" }
          end

        when "sqlite"
          db_dir = File.expand_path("../../db", __dir__)
          sqlite_files = Dir.glob("#{db_dir}/*.{sqlite,sqlite3,db}").map { |f| "db/#{File.basename(f)}" }
          { success: true, databases: sqlite_files, is_pgbouncer: false, message: "SQLite databases are file-based." }
        else
          { success: false, message: "Unsupported adapter: #{adapter}" }
        end
      end

      def with_connection(id_or_config)
        config = if id_or_config.is_a?(String)
                   load_storage.find { |c| c["id"] == id_or_config } || raise("Connection #{id_or_config} not found")
                 else
                   id_or_config
                 end

        id = config["id"] || config[:id] || "temp"
        db = @pools[id]

        if db.nil? || !alive?(db)
          url = build_connection_url(config)
          opts = { max_connections: 4, timeout: 10, connect_timeout: 5 }

          if config["adapter"].to_s == "postgres" || config[:adapter].to_s == "postgres"
            opts[:client_min_messages] = false
          end

          db = Sequel.connect(url, opts)

          if config["adapter"].to_s == "postgres" || config[:adapter].to_s == "postgres"
            db.extension :pg_array if db.respond_to?(:extension)
            db.extension :pg_json if db.respond_to?(:extension)
          end

          @pools[id] = db
        end

        yield db
      end

      def disconnect(id)
        if (db = @pools.delete(id))
          db.disconnect rescue nil
        end
      end

      def disconnect_all
        @pools.each_value { |db| db.disconnect rescue nil }
        @pools.clear
      end

      def build_connection_url(config)
        adapter = (config["adapter"] || config[:adapter] || "postgres").to_s.downcase

        case adapter
        when "sqlite"
          path = config["file_path"] || config[:file_path] || DemoDatabase::DEFAULT_PATH
          abs_path = File.expand_path(path, Dir.pwd)
          "sqlite://#{abs_path}"
        when "postgres", "postgresql"
          host = config["host"] || config[:host] || "localhost"
          host = "localhost" if host.to_s.strip.empty?
          port = (config["port"] || config[:port] || 5432).to_i
          port = 5432 if port <= 0
          raw_db = (config["database"] || config[:database]).to_s.strip
          db   = raw_db.empty? ? "postgres" : raw_db
          user = (config["username"] || config[:username]).to_s
          pass = (config["password"] || config[:password]).to_s
          ssl  = config["ssl"] || config[:ssl]

          require "cgi"
          auth = if user.empty?
                   ""
                 elsif pass.empty?
                   "#{CGI.escape(user)}@"
                 else
                   "#{CGI.escape(user)}:#{CGI.escape(pass)}@"
                 end

          query_params = []
          query_params << "sslmode=require" if ssl

          qs = query_params.empty? ? "" : "?#{query_params.join('&')}"
          "postgres://#{auth}#{host}:#{port}/#{db}#{qs}"
        when "mysql", "mysql2"
          host = config["host"] || config[:host] || "localhost"
          port = (config["port"] || config[:port] || 3306).to_i
          port = 3306 if port <= 0
          raw_db = (config["database"] || config[:database]).to_s.strip
          db   = raw_db.empty? ? "" : raw_db
          user = (config["username"] || config[:username]).to_s
          pass = (config["password"] || config[:password]).to_s

          require "cgi"
          auth = if user.empty?
                   ""
                 elsif pass.empty?
                   "#{CGI.escape(user)}@"
                 else
                   "#{CGI.escape(user)}:#{CGI.escape(pass)}@"
                 end

          "mysql2://#{auth}#{host}:#{port}/#{db}"
        else
          raise "Unsupported adapter: #{adapter}"
        end
      end

      private

      def alive?(db)
        db.test_connection
        true
      rescue StandardError
        false
      end

      def ensure_storage!
        FileUtils.mkdir_p(File.dirname(STORAGE_FILE))
        demo_path = DemoDatabase.ensure_seeded!

        unless File.exist?(STORAGE_FILE)
          initial = [
            {
              "id" => "demo-sqlite",
              "name" => "Demo Store (SQLite)",
              "adapter" => "sqlite",
              "file_path" => demo_path,
              "is_demo" => true,
              "created_at" => Time.now.iso8601
            }
          ]
          save_storage(initial)
        end
      end

      def load_storage
        JSON.parse(File.read(STORAGE_FILE))
      rescue StandardError
        []
      end

      def save_storage(data)
        File.write(STORAGE_FILE, JSON.pretty_generate(data))
      end
    end
  end
end
