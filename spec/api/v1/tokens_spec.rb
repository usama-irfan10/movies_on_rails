require "swagger_helper"

RSpec.describe "API v1: tokens", type: :request do
  let(:user) { create(:user) }

  path "/api/v1/tokens" do
    post "Create a token" do
      tags "Authentication"
      description "Exchanges an email address and password for a bearer token, valid for 30 days. " \
                  "The token is shown only in this response."
      operationId "createToken"
      security []
      consumes "application/json"
      produces "application/json"
      parameter name: :credentials, in: :body, schema: { "$ref" => "#/components/schemas/Credentials" }

      response "201", "Token created" do
        schema "$ref" => "#/components/schemas/Token"
        let(:credentials) { { email_address: user.email_address, password: user.password } }

        run_test! do
          expect(ApiToken.find_active_by_plaintext(response.parsed_body["token"]).user).to eq(user)
        end
      end

      response "401", "Wrong email address or password" do
        schema "$ref" => "#/components/schemas/Error"
        let(:credentials) { { email_address: user.email_address, password: "wrong" } }

        run_test!
      end
    end

    delete "Revoke the current token" do
      tags "Authentication"
      description "Revokes the token sent in the Authorization header. Other tokens stay valid."
      operationId "revokeToken"
      produces "application/json"

      response "204", "Token revoked" do
        let(:token) { ApiToken.issue_for(user) }
        let(:Authorization) { "Bearer #{token.plaintext}" }

        run_test! do
          expect(ApiToken.exists?(token.id)).to be(false)
        end
      end

      response "401", "Missing, invalid or expired token" do
        schema "$ref" => "#/components/schemas/Error"
        let(:Authorization) { "Bearer not-a-token" }

        run_test!
      end
    end
  end
end
