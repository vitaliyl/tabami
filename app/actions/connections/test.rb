# frozen_string_literal: true

module Tabami
  module Actions
    module Connections
      class Test < Tabami::Action
        params do
          optional(:connection).hash do
            optional(:adapter).maybe(:string)
            optional(:host).maybe(:string)
            optional(:port).maybe(:integer)
            optional(:database).maybe(:string)
            optional(:username).maybe(:string)
            optional(:password).maybe(:string)
            optional(:file_path).maybe(:string)
            optional(:ssl).maybe(:bool)
          end
          optional(:adapter).maybe(:string)
          optional(:host).maybe(:string)
          optional(:port).maybe(:integer)
          optional(:database).maybe(:string)
          optional(:username).maybe(:string)
          optional(:password).maybe(:string)
          optional(:file_path).maybe(:string)
          optional(:ssl).maybe(:bool)
        end

        def handle(request, response)
          conn_params = request.params[:connection] || request.params.to_h
          result = connection_manager.test_connection(conn_params)

          response.format = :json
          response.status = result[:success] ? 200 : 422
          response.body = result.to_json
        end
      end
    end
  end
end
