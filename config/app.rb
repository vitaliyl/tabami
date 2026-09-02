# frozen_string_literal: true

require "hanami"
require "rack/static"

module Tabami
  class App < Hanami::App
    config.middleware.use Rack::Static, urls: ["/dist", "/assets"], root: "public"
    config.middleware.use :body_parser, :json

    config.actions.csrf_protection = false

    config.actions.sessions = :cookie, {
      key: "_tabami_session",
      secret: ENV.fetch("SESSION_SECRET", "a_very_long_secure_secret_key_for_tabami_database_studio_sessions_1234567890_abcdefghijklmnopqrstuvwxyz_0987654321_zyxwvutsrqponmlkjihgfedcba"),
      expire_after: 60 * 60 * 24 * 30 # 30 days
    }

    if config.actions.content_security_policy
      config.actions.content_security_policy[:script_src] += " 'unsafe-inline' 'unsafe-eval' http://localhost:5173 http://127.0.0.1:5173"
      config.actions.content_security_policy[:connect_src] += " http://localhost:5173 http://127.0.0.1:5173 ws://localhost:5173 ws://127.0.0.1:5173"
      config.actions.content_security_policy[:font_src] += " https://fonts.gstatic.com data:"
      config.actions.content_security_policy[:style_src] += " https://fonts.googleapis.com 'unsafe-inline'"
      config.actions.content_security_policy[:img_src] += " https: data:"
    end
  end
end
