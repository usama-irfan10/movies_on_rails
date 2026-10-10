require "rails_helper"

RSpec.describe "Authentication", type: :request do
  let(:user) { create(:user) }

  describe "protected pages" do
    it "redirects visitors to the sign-in page" do
      get root_path
      expect(response).to redirect_to(new_session_path)

      get movies_path
      expect(response).to redirect_to(new_session_path)
    end

    it "keeps the health check public" do
      get rails_health_check_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "signing in" do
    it "starts a session and sends the user back to the page they asked for" do
      get movies_path, params: { actor: "cage" }

      post session_path, params: { email_address: user.email_address, password: user.password }

      expect(response).to redirect_to("/movies?actor=cage")
      expect(Session.where(user:).count).to eq(1)

      get movies_path
      expect(response).to have_http_status(:ok)
    end

    it "sets an HttpOnly, SameSite cookie" do
      post session_path, params: { email_address: user.email_address, password: user.password }

      cookie = Array(response.headers["Set-Cookie"]).join("\n") # an Array on Rack 3
      expect(cookie).to match(/session_id=[^\n]*httponly/i)
      expect(cookie).to match(/session_id=[^\n]*samesite=lax/i)
    end

    it "accepts the email address in any case" do
      post session_path, params: { email_address: user.email_address.upcase, password: user.password }

      expect(response).to redirect_to(root_url)
    end

    it "rejects a wrong password without creating a session, keeping the email filled in" do
      post session_path, params: { email_address: user.email_address, password: "wrong" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Try another email address or password.")
      expect(response.body).to include(%(value="#{user.email_address}"))
      expect(response.body).not_to include(%(value="wrong")) # the password is never echoed back
      expect(Session.count).to eq(0)
      get movies_path
      expect(response).to redirect_to(new_session_path)
    end

    it "gives the same answer for unknown emails" do
      post session_path, params: { email_address: user.email_address, password: "wrong" }
      known = response.body[/<p class="flash alert"[^>]*>([^<]+)</, 1]

      post session_path, params: { email_address: "nobody@example.com", password: "wrong" }

      expect(response.body[/<p class="flash alert"[^>]*>([^<]+)</, 1]).to eq(known)
    end

    it "does not blow up on missing or malformed credentials" do
      post session_path
      expect(response).to have_http_status(:unprocessable_content)

      post session_path, params: { email_address: [ "a" ], password: { b: "c" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).not_to include("[&quot;a&quot;]")
    end
  end

  describe "signing out" do
    it "destroys the session" do
      sign_in(user)

      delete session_path

      expect(response).to redirect_to(new_session_path)
      expect(Session.count).to eq(0)
      get movies_path
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "session expiry" do
    it "rejects sessions older than #{Session::MAX_AGE.inspect}" do
      sign_in(user)
      Session.last.update_columns(created_at: Session::MAX_AGE.ago - 1.minute)

      get movies_path

      expect(response).to redirect_to(new_session_path)
    end
  end
end
