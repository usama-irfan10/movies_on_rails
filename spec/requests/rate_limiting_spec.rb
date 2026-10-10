require "rails_helper"

RSpec.describe "Rate limiting", type: :request do
  # Rails.cache is a null store in tests, so give Rack::Attack a real one.
  around do |example|
    original = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rack::Attack.cache.store = original
  end

  it "throttles repeated token requests with a JSON 429" do
    credentials = { email_address: "nobody@example.com", password: "wrong" }

    10.times { post "/api/v1/tokens", params: credentials, as: :json }
    expect(response).to have_http_status(:unauthorized)

    post "/api/v1/tokens", params: credentials, as: :json

    expect(response).to have_http_status(:too_many_requests)
    expect(response.parsed_body).to eq("error" => "Too many requests")
    expect(response.headers["Retry-After"]).to be_present
  end

  it "throttles password reset requests" do
    5.times { post passwords_path, params: { email_address: "nobody@example.com" } }
    expect(response).to have_http_status(:found)

    post passwords_path, params: { email_address: "nobody@example.com" }

    expect(response).to have_http_status(:too_many_requests)
  end
end
