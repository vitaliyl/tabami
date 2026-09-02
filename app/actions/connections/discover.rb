# frozen_string_literal: true

module Tabami
  module Actions
    module Connections
      class Discover < Tabami::Action
        def handle(request, response)
          conn_params = request.params[:connection] || request.params
          result = connection_manager.discover_databases(conn_params)

          response.format = :json
          response.status = result[:success] ? 200 : 422
          response.body = result.to_json
        end
      end
    end
  end
end
