# frozen_string_literal: true

module Tabami
  module Actions
    module Explorer
      class Structure < Tabami::Action
        params do
          required(:table).filled(:string)
          optional(:connection_id).maybe(:string)
          optional(:schema).maybe(:string)
        end

        def handle(request, response)
          conn_id = request.params[:connection_id] || active_connection_id(request)
          table = request.params[:table]
          schema = request.params[:schema] || "public"
          structure = nil

          if conn_id && table && (conn_info = connection_manager.find(conn_id))
            connection_manager.with_connection(conn_id) do |db|
              structure = Services::SchemaInspector.inspect_structure(db, conn_info[:adapter], table, schema)
            end
          end

          response.format = :json
          if structure
            response.body = structure.to_json
          else
            response.status = 404
            response.body = { error: "Table structure not found" }.to_json
          end
        end
      end
    end
  end
end
