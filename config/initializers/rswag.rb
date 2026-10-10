# Interactive API documentation at /api-docs (development and test only; see
# config/routes.rb). The OpenAPI file is generated from spec/api by
# `bin/rails rswag:specs:swaggerize` and committed in swagger/v1/openapi.yaml.
#
# Swagger UI uses inline scripts. That works because the Content-Security-Policy
# is report-only in development (config/initializers/content_security_policy.rb).
if defined?(Rswag::Api)
  Rswag::Api.configure do |config|
    config.openapi_root = Rails.root.join("swagger").to_s
  end

  Rswag::Ui.configure do |config|
    config.openapi_endpoint "/api-docs/v1/openapi.yaml", "Movies on Rails API v1"
  end
end
