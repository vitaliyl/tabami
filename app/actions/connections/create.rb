# frozen_string_literal: true

module Tabami
  module Actions
    module Connections
      class Create < Tabami::Action
        params do
          optional(:connection).hash do
            optional(:name).maybe(:string)
            optional(:adapter).maybe(:string)
            optional(:host).maybe(:string)
            optional(:port).maybe(:integer)
            optional(:database).maybe(:string)
            optional(:username).maybe(:string)
            optional(:password).maybe(:string)
            optional(:file_path).maybe(:string)
            optional(:ssl).maybe(:bool)
          end
          optional(:name).maybe(:string)
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
          created = connection_manager.create(conn_params)

          if created
            request.session[:active_connection_id] = created[:id]
            request.session[:notice] = "Connection '#{created[:name]}' added successfully."
          else
            request.session[:alert] = "Failed to add connection."
          end

          response.redirect_to "/", status: 303
        end
      end
    end
  end
end
