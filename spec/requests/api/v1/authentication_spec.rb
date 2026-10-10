require "rails_helper"

RSpec.describe "API v1 authentication", type: :request do
  let(:user) { create(:user) }
  let(:movie) { create(:movie) }

  def bearer(token)
    { "Authorization" => "Bearer #{token}" }
  end

  describe "protected endpoints" do
    it "rejects requests without a token" do
      get "/api/v1/movies"

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to start_with("Bearer")
      expect(json).to eq("error" => "Unauthorized")
    end

    it "rejects the show and reviews endpoints without a token" do
      get "/api/v1/movies/#{movie.id}"
      expect(response).to have_http_status(:unauthorized)

      get "/api/v1/movies/#{movie.id}/reviews"
      expect(response).to have_http_status(:unauthorized)
    end

    it "checks the token before looking up records or routes" do
      get "/api/v1/movies/0"
      expect(response).to have_http_status(:unauthorized)

      get "/api/v1/nope"
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects unknown tokens and other schemes" do
      get "/api/v1/movies", headers: bearer("not-a-token")
      expect(response).to have_http_status(:unauthorized)

      get "/api/v1/movies", headers: { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("a", "b") }
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects expired tokens" do
      token = ApiToken.issue_for(user)
      token.update!(expires_at: 1.minute.ago)

      get "/api/v1/movies", headers: bearer(token.plaintext)

      expect(response).to have_http_status(:unauthorized)
    end

    it "does not accept a browser session cookie" do
      sign_in(user)

      get "/api/v1/movies"

      expect(response).to have_http_status(:unauthorized)
    end

    it "accepts a valid token and records its use" do
      token = ApiToken.issue_for(user)

      get "/api/v1/movies", headers: bearer(token.plaintext)

      expect(response).to have_http_status(:ok)
      expect(token.reload.last_used_at).to be_present
    end
  end

  describe "POST /api/v1/tokens" do
    it "exchanges valid credentials for a bearer token" do
      post "/api/v1/tokens", params: { email_address: user.email_address, password: user.password }, as: :json

      expect(response).to have_http_status(:created)
      expect(response.headers["Cache-Control"]).to include("no-store")
      expect(json).to include("token_type" => "Bearer", "token" => be_present, "expires_at" => be_present)

      get "/api/v1/movies", headers: bearer(json["token"])
      expect(response).to have_http_status(:ok)
    end

    it "stores only a digest of the token" do
      post "/api/v1/tokens", params: { email_address: user.email_address, password: user.password }, as: :json

      expect(ApiToken.pluck(:token_digest)).not_to include(json["token"])
      expect(ApiToken.find_active_by_plaintext(json["token"]).user).to eq(user)
    end

    it "rejects a wrong password and an unknown user alike" do
      post "/api/v1/tokens", params: { email_address: user.email_address, password: "wrong" }, as: :json
      expect(response).to have_http_status(:unauthorized)
      wrong_password_body = json

      post "/api/v1/tokens", params: { email_address: "nobody@example.com", password: "wrong" }, as: :json
      expect(response).to have_http_status(:unauthorized)
      expect(json).to eq(wrong_password_body)
      expect(ApiToken.count).to eq(0)
    end

    it "answers a malformed JSON body with a JSON 400" do
      post "/api/v1/tokens", params: "{not json", headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:bad_request)
      expect(json).to eq("error" => "Malformed request body")
    end

    it "does not blow up on missing or malformed credentials" do
      post "/api/v1/tokens", params: { email_address: [ "a" ], password: { b: "c" } }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/tokens" do
    it "revokes the token that made the request" do
      token = ApiToken.issue_for(user)

      delete "/api/v1/tokens", headers: bearer(token.plaintext)
      expect(response).to have_http_status(:no_content)

      get "/api/v1/movies", headers: bearer(token.plaintext)
      expect(response).to have_http_status(:unauthorized)
    end

    it "requires a token" do
      delete "/api/v1/tokens"

      expect(response).to have_http_status(:unauthorized)
    end

    it "leaves the user's other tokens working" do
      first = ApiToken.issue_for(user)
      second = ApiToken.issue_for(user)

      delete "/api/v1/tokens", headers: bearer(first.plaintext)

      get "/api/v1/movies", headers: bearer(second.plaintext)
      expect(response).to have_http_status(:ok)
    end
  end
end
