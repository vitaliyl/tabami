# frozen_string_literal: true

module Tabami
  module Actions
    module Query
      class Execute < Tabami::Action
        params do
          required(:sql).filled(:string)
          optional(:connection_id).maybe(:string)
          optional(:limit).maybe(:integer)
        end

        def handle(request, response)
          conn_id = request.params[:connection_id] || active_connection_id(request)
          sql = request.params[:sql]
          limit = (request.params[:limit] || 500).to_i

          result = nil
          if conn_id && sql && (conn_info = connection_manager.find(conn_id))
            connection_manager.with_connection(conn_id) do |db|
              case Services::QueryRunner.execute_monad(db, sql, limit: limit, adapter: conn_info[:adapter])
              in Success(query_result)
                result = query_result.to_h
              in Failure(err_hash)
                result = err_hash
              end
            end
          else
            result = { success: false, error: "Missing connection or SQL query" }
          end

          response.format = :json
          response.status = 200
          response.body = result.to_json
        end
      end
    end
  end
end
