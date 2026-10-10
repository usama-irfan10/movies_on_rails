module Api
  module V1
    # Every API endpoint requires `Authorization: Bearer <token>` unless it opts out.
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate_api_token!
      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActionDispatch::Http::Parameters::ParseError, with: :bad_request

      private
        attr_reader :current_api_token

        def authenticate_api_token!
          @current_api_token = authenticate_with_http_token do |plaintext, _options|
            ApiToken.find_active_by_plaintext(plaintext)
          end

          return render_unauthorized unless current_api_token

          current_api_token.record_usage!
        end

        def render_unauthorized(message = "Unauthorized")
          response.set_header("WWW-Authenticate", 'Bearer realm="Movies on Rails API"')
          render json: { error: message }, status: :unauthorized
        end

        def not_found
          render json: { error: "Not found" }, status: :not_found
        end

        def bad_request
          render json: { error: "Malformed request body" }, status: :bad_request
        end
    end
  end
end
