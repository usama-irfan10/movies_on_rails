module Api
  module V1
    # Shared behaviour for all v1 endpoints: errors are always JSON.
    class BaseController < ActionController::API
      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActionDispatch::Http::Parameters::ParseError, with: :bad_request

      private
        def not_found
          render json: { error: "Not found" }, status: :not_found
        end

        def bad_request
          render json: { error: "Malformed request body" }, status: :bad_request
        end
    end
  end
end
