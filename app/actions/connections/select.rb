# frozen_string_literal: true

module Tabami
  module Actions
    module Connections
      class Select < Tabami::Action
        def handle(request, response)
          conn_id = request.params[:id]
          if conn_id && connection_manager.find(conn_id)
            request.session[:active_connection_id] = conn_id
          end

          response.redirect_to "/", status: 303
        end
      end
    end
  end
end
