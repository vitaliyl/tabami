# frozen_string_literal: true

module Tabami
  module Actions
    module Connections
      class Destroy < Tabami::Action
        def handle(request, response)
          conn_id = request.params[:id]
          if conn_id
            deleted = connection_manager.delete(conn_id)
            if deleted
              request.session[:notice] = "Connection deleted."
              if request.session[:active_connection_id] == conn_id
                request.session[:active_connection_id] = connection_manager.all_connections.first&.dig(:id)
              end
            else
              request.session[:alert] = "Cannot delete built-in demo connection."
            end
          end

          response.redirect_to "/", status: 303
        end
      end
    end
  end
end
