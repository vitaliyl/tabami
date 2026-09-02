# frozen_string_literal: true

require "json"
require_relative "inertia/version"

module Hanami
  module Inertia
    def inertia(request, response, component, props = {})
      page_data = {
        component: component,
        props: props,
        url: request.fullpath,
        version: inertia_version
      }

      if request.env["HTTP_X_INERTIA"]
        response.headers["X-Inertia"] = "true"
        response.headers["Vary"] = "X-Inertia"
        response.format = :json
        response.body = page_data.to_json
      else
        response.format = :html
        response.body = render_inertia_layout(page_data)
      end
    end

    def inertia_version
      @inertia_version ||= "1.0"
    end

    def render_inertia_layout(page_data)
      <<~HTML
        <!DOCTYPE html>
        <html lang="en" class="h-full bg-slate-950">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>Hanami App</title>
          </head>
          <body class="h-full antialiased overflow-hidden bg-slate-950 text-slate-100">
            <div id="app" data-page='#{ERB::Util.html_escape(page_data.to_json)}'></div>
          </body>
        </html>
      HTML
    end
  end
end
