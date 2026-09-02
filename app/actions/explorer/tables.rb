# frozen_string_literal: true

module Tabami
  module Actions
    module Explorer
      class Tables < Tabami::Action
        params do
          optional(:connection_id).maybe(:string)
          optional(:schema).maybe(:string)
        end

        def handle(request, response)
          conn_id = request.params[:connection_id] || active_connection_id(request)
          schema = request.params[:schema] || "public"
          tables = []

          if conn_id && (conn_info = connection_manager.find(conn_id))
            connection_manager.with_connection(conn_id) do |db|
              tables = Services::SchemaInspector.inspect_tables(db, conn_info[:adapter], schema)
            end
          end

          response.format = :json
          response.body = { tables: tables, schema: schema }.to_json
        end
      end
    end
  end
end
