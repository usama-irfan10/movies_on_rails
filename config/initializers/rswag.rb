# Interactive API documentation at /api-docs (see config/routes.rb). The OpenAPI file
# is generated from spec/api by `bin/rails rswag:specs:swaggerize` and committed in
# swagger/v1/openapi.yaml.
#
# Swagger UI needs inline scripts and styles. Its index page sends its own
# Content-Security-Policy that allows them; the strict app-wide policy is skipped under
# /api-docs only (see config/initializers/content_security_policy.rb).
Rswag::Api.configure do |config|
  config.openapi_root = Rails.root.join("swagger").to_s
end

Rswag::Ui.configure do |config|
  config.openapi_endpoint "/api-docs/v1/openapi.yaml", "Movies on Rails API v1"
end
