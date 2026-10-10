require "rails_helper"

RSpec.describe "Security headers", type: :request do
  it "sends a strict Content-Security-Policy" do
    get new_session_path

    policy = response.headers["Content-Security-Policy"]
    expect(policy).to include("default-src 'self'", "object-src 'none'", "frame-ancestors 'none'")
  end
end
