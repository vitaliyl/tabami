# frozen_string_literal: true

require "hanami/action"
require "dry/monads"
require "dry/monads/do"
require_relative "types"
require_relative "structs"
require_relative "inertia"
require_relative "services/connection_manager"
require_relative "services/schema_inspector"
require_relative "services/query_runner"

module Tabami
  class Action < Hanami::Action
    include Dry::Monads[:result, :do]
    include Tabami::Inertia

    def connection_manager
      Tabami::Services::ConnectionManager.new
    end

    def active_connection_id(request)
      request.session[:active_connection_id] || connection_manager.all_connections.first&.dig(:id)
    end

    def validate_params!(request, response)
      return true if request.params.valid?

      response.format = :json
      response.status = 422
      response.body = {
        success: false,
        error: "Validation failed: #{request.params.errors.to_h}",
        errors: request.params.errors.to_h
      }.to_json
      false
    end

    def respond_with(result, response, success_status: 200)
      response.format = :json

      case result
      when Dry::Monads::Success
        val = result.value!
        response.status = success_status
        body_data = val.respond_to?(:to_h) ? val.to_h : val
        response.body = body_data.is_a?(Hash) && body_data.key?(:success) ? body_data.to_json : { success: true, data: body_data }.to_json
      when Dry::Monads::Failure
        err = result.failure
        response.status = err.is_a?(Hash) && err[:status] ? err[:status] : 422
        body_data = err.respond_to?(:to_h) ? err.to_h : { error: err.to_s }
        response.body = body_data.is_a?(Hash) && body_data.key?(:success) ? body_data.to_json : { success: false, error: body_data[:error] || body_data.to_s }.to_json
      else
        response.status = success_status
        response.body = (result.respond_to?(:to_h) ? result.to_h : result).to_json
      end
    end
  end
end
