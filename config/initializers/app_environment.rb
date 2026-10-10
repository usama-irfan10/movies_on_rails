# Fails fast with a clear message when production is missing required settings,
# and locks the app to its own host name (protects against DNS rebinding).
#
# Skipped while building images (SECRET_KEY_BASE_DUMMY is set during assets:precompile).
if Rails.env.production? && ENV["SECRET_KEY_BASE_DUMMY"].blank?
  required = %w[APP_HOST]
  missing = required.select { |name| ENV[name].blank? }
  raise "Missing required environment variables: #{missing.join(', ')}. See .env.example." if missing.any?

  Rails.application.config.hosts << ENV.fetch("APP_HOST").split(":").first
  Rails.application.config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
