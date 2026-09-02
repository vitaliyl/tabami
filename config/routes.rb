# frozen_string_literal: true

require "hanami/routes"

module Tabami
  class Routes < Hanami::Routes
    root to: "dashboard.index"

    post "/connections", to: "connections.create"
    post "/connections/test", to: "connections.test"
    post "/connections/discover", to: "connections.discover"
    post "/connections/:id/select", to: "connections.select"
    delete "/connections/:id", to: "connections.destroy"

    get "/api/tables", to: "explorer.tables"
    get "/api/structure", to: "explorer.structure"
    post "/api/query", to: "query.execute"
  end
end
