# frozen_string_literal: true

module Tabami
  module Actions
    module Dashboard
      class Index < Tabami::Action
        def handle(request, response)
          conn_id = request.params[:connection_id] || active_connection_id(request)
          request.session[:active_connection_id] = conn_id if conn_id

          conn_info = connection_manager.find(conn_id)
          schemas = []
          tables = []
          selected_schema = request.params[:schema] || "public"
          selected_table = request.params[:table]

          table_structure = nil

          if conn_info
            connection_manager.disconnect(conn_id) if request.params[:refresh]

            connection_manager.with_connection(conn_id) do |db|
              adapter = conn_info[:adapter]
              schemas = Services::SchemaInspector.inspect_schemas(db, adapter)
              selected_schema = schemas.first if !schemas.include?(selected_schema) && schemas.any?

              tables = Services::SchemaInspector.inspect_tables(db, adapter, selected_schema)

              if selected_table
                table_structure = Services::SchemaInspector.inspect_structure(db, adapter, selected_table, selected_schema)
              end
            end
          end

          inertia request, response, "Dashboard", {
            active_connection: conn_info,
            schemas: schemas,
            selected_schema: selected_schema,
            tables: tables,
            selected_table: selected_table,
            table_structure: table_structure,
            query_tab: request.params[:tab] || (selected_table ? "structure" : "domains")
          }
        end
      end
    end
  end
end
