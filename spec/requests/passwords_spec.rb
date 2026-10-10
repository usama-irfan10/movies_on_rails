require "rails_helper"

RSpec.describe "Password resets", type: :request do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }
  let(:new_password) { "a-brand-new-password" }

  describe "POST /passwords" do
    it "queues reset instructions for an existing account" do
      expect { post passwords_path, params: { email_address: user.email_address } }
        .to have_enqueued_mail(PasswordsMailer, :reset).with(user)

      expect(response).to redirect_to(new_session_path)
    end

    it "answers identically for unknown accounts and sends nothing" do
      post passwords_path, params: { email_address: "nobody@example.com" }
      unknown_notice = flash[:notice]

      expect { post passwords_path, params: { email_address: user.email_address } }
        .to have_enqueued_mail(PasswordsMailer, :reset)
      expect(flash[:notice]).to eq(unknown_notice)

      expect { post passwords_path, params: { email_address: "nobody@example.com" } }
        .not_to have_enqueued_mail
    end

    it "does not blow up on malformed input" do
      post passwords_path, params: { email_address: { a: "b" } }

      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "GET /passwords/:token/edit" do
    it "shows the form for a valid token" do
      get edit_password_path(user.password_reset_token)

      expect(response).to have_http_status(:ok)
    end

    it "rejects an invalid token" do
      get edit_password_path("not-a-real-token")

      expect(response).to redirect_to(new_password_path)
      expect(flash[:alert]).to include("invalid or has expired")
    end

    it "rejects an expired token" do
      token = user.password_reset_token

      travel_to(20.minutes.from_now) { get edit_password_path(token) }

      expect(response).to redirect_to(new_password_path)
    end
  end

  describe "PUT /passwords/:token" do
    it "sets the new password and signs the user out everywhere" do
      sign_in(user)
      token = user.password_reset_token

      put password_path(token), params: { password: new_password, password_confirmation: new_password }

      expect(response).to redirect_to(new_session_path)
      expect(User.authenticate_by(email_address: user.email_address, password: new_password)).to eq(user)
      expect(user.sessions).to be_empty
    end

    it "makes the token single-use" do
      token = user.password_reset_token
      put password_path(token), params: { password: new_password, password_confirmation: new_password }

      get edit_password_path(token)

      expect(response).to redirect_to(new_password_path)
    end

    it "rejects mismatched confirmation, short and blank passwords" do
      token = user.password_reset_token

      put password_path(token), params: { password: new_password, password_confirmation: "different" }
      expect(response).to redirect_to(edit_password_path(token))

      put password_path(token), params: { password: "short", password_confirmation: "short" }
      expect(flash[:alert]).to include("too short")

      put password_path(token), params: { password: "", password_confirmation: "" }
      expect(response).to redirect_to(edit_password_path(token))

      expect(User.authenticate_by(email_address: user.email_address, password: user.password)).to eq(user)
    end
  end
end
