# frozen_string_literal: true

require "json"
require "cgi"
require "socket"
require "net/http"
require "uri"

module Tabami
  module Inertia
    def self.included(base)
      base.class_eval do
        before :check_inertia_version
      end
    end

    private

    def inertia(request, response, component, props = {})
      current_version = inertia_version
      url = request.fullpath

      resolved_props = resolve_props(request, component, props)
      page = {
        component: component,
        props: resolved_props,
        url: url,
        version: current_version
      }

      if inertia_request?(request)
        response.status = 200
        response.headers["X-Inertia"] = "true"
        response.headers["Vary"] = "Accept"
        response.format = :json
        response.body = page.to_json
      else
        response.format = :html
        response.body = render_inertia_html(page)
      end
    end

    def inertia_request?(request)
      request.env["HTTP_X_INERTIA"] == "true"
    end

    def inertia_version
      manifest_path = File.expand_path("../public/dist/.vite/manifest.json", __dir__)
      manifest_path = File.expand_path("../public/dist/manifest.json", __dir__) unless File.exist?(manifest_path)

      if File.exist?(manifest_path)
        File.mtime(manifest_path).to_i.to_s
      else
        ENV.fetch("APP_VERSION", "0.1.0")
      end
    end

    def check_inertia_version(request, response)
      return unless inertia_request?(request) && request.get?

      client_version = request.env["HTTP_X_INERTIA_VERSION"]
      if client_version && client_version != inertia_version
        response.status = 409
        response.headers["X-Inertia-Location"] = request.fullpath
        halt 409
      end
    end

    def resolve_props(request, component, props)
      all_props = shared_props(request).merge(props)

      if partial_reload?(request, component)
        raw_keys = request.env["HTTP_X_INERTIA_PARTIAL_DATA"].to_s
        requested_keys = raw_keys.split(",").map(&:strip).map(&:to_sym)
        all_props.select! { |k, _| requested_keys.include?(k) }
      end

      all_props.transform_values { |v| v.respond_to?(:call) ? v.call : v }
    end

    def partial_reload?(request, component)
      inertia_request?(request) && request.env["HTTP_X_INERTIA_PARTIAL_COMPONENT"] == component
    end

    def shared_props(request)
      flash_notice = request.session[:notice]
      flash_alert = request.session[:alert]
      request.session.delete(:notice)
      request.session.delete(:alert)

      conn_mgr = Tabami::Services::ConnectionManager.new
      connections = conn_mgr.all_connections
      active_conn_id = request.session[:active_connection_id] || connections.first&.dig(:id)

      {
        flash: {
          notice: flash_notice,
          alert: flash_alert
        },
        connections: connections,
        active_connection_id: active_conn_id
      }
    end

    def vite_dev_server_running?
      return false if ENV["VITE_DEV_SERVER"] == "false"
      return false if defined?(Hanami) && Hanami.respond_to?(:env) && Hanami.env == :production

      ["localhost", "127.0.0.1"].any? do |host|
        begin
          uri = URI("http://#{host}:5173/@vite/client")
          http = Net::HTTP.new(uri.host, uri.port)
          http.open_timeout = 0.2
          http.read_timeout = 0.2
          res = http.request_get(uri.request_uri)
          res.is_a?(Net::HTTPSuccess)
        rescue StandardError
          false
        end
      end
    end

    def render_inertia_html(page)
      page_json = CGI.escapeHTML(page.to_json)

      manifest_path = File.expand_path("../public/dist/.vite/manifest.json", __dir__)
      manifest_path = File.expand_path("../public/dist/manifest.json", __dir__) unless File.exist?(manifest_path)

      script_tag = if vite_dev_server_running?
                     <<~HTML
                       <script type="module" src="http://localhost:5173/@vite/client"></script>
                       <script type="module" src="http://localhost:5173/app/assets/js/app.ts"></script>
                     HTML
                   elsif File.exist?(manifest_path)
                     manifest = begin
                       JSON.parse(File.read(manifest_path))
                     rescue StandardError
                       {}
                     end
                     entry = manifest["app/assets/js/app.ts"] || manifest["app/assets/js/app.js"] || {}
                     js_file = entry["file"] ? "/dist/#{entry['file']}" : "/dist/app.js"
                     css_files = (entry["css"] || []).map { |c| %(<link rel="stylesheet" href="/dist/#{c}">) }.join("\n")
                     %(#{css_files}\n<script type="module" src="#{js_file}"></script>)
                   else
                     %(<script type="module" src="/dist/app.js"></script>)
                   end

      <<~HTML
        <!DOCTYPE html>
        <html lang="en" class="h-full antialiased dark">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Tabami | Database Studio</title>
            <link rel="icon" type="image/svg+xml" href="/favicon.svg">
            <link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png">
            <link rel="icon" type="image/png" sizes="16x16" href="/favicon-16x16.png">
            <link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">
            <link rel="manifest" href="/site.webmanifest">
            <script>
              (function() {
                try {
                  var saved = localStorage.getItem('tabami_theme') || 'dark';
                  document.documentElement.classList.remove('dark', 'light', 'matcha');
                  if (saved === 'light' || saved === 'matcha') {
                    document.documentElement.classList.add(saved);
                  } else {
                    document.documentElement.classList.add('dark');
                  }
                } catch (e) {}
              })();
            </script>
            <link rel="preconnect" href="https://fonts.googleapis.com">
            <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
            <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600&family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
            #{script_tag}
          </head>
          <body class="h-full overflow-hidden font-sans">
            <div id="app" data-page="#{page_json}"></div>
          </body>
        </html>
      HTML
    end
  end
end
