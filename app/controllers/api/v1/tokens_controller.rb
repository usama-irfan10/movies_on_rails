module Api
  module V1
    class TokensController < BaseController
      skip_before_action :authenticate_api_token!, only: :create

      # POST /api/v1/tokens  { "email_address": "...", "password": "..." }
      # The plaintext token is returned once and cannot be retrieved again.
      def create
        user = User.authenticate_by(email_address: params[:email_address].to_s, password: params[:password].to_s)
        return render_unauthorized("Invalid email address or password") unless user

        token = ApiToken.issue_for(user)
        response.set_header("Cache-Control", "no-store")
        render json: { token: token.plaintext, token_type: "Bearer", expires_at: token.expires_at }, status: :created
      end

      # DELETE /api/v1/tokens - revokes the token used to make this request.
      def destroy
        current_api_token.destroy!
        head :no_content
      end
    end
  end
end
