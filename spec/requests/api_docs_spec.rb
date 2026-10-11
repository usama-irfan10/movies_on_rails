require "rails_helper"

RSpec.describe "API documentation" do
  it "redirects /api-docs to Swagger UI" do
    get "/api-docs"

    expect(response).to redirect_to("/api-docs/index.html")
  end

  it "serves Swagger UI without signing in, with its own Content-Security-Policy" do
    get "/api-docs/index.html"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("/api-docs/v1/openapi.yaml")
    policy = response.headers["Content-Security-Policy"]
    expect(policy).to include("script-src 'self' 'unsafe-inline'")
    expect(policy).not_to include("object-src 'none'") # the app-wide policy is not added on top
  end

  it "serves the OpenAPI document" do
    get "/api-docs/v1/openapi.yaml"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("openapi: 3")
  end

  it "keeps the strict policy on application pages" do
    get new_session_path

    expect(response.headers["Content-Security-Policy"]).to include("script-src 'self'")
    expect(response.headers["Content-Security-Policy"]).not_to include("unsafe-inline")
  end
end
