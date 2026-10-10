# Fails fast with a clear message when production is missing required settings,
# and locks the app to its own host name (protects against DNS rebinding).
#
# Skipped while building images (SECRET_KEY_BASE_DUMMY is set during assets:precompile).
if Rails.env.production? && ENV["SECRET_KEY_BASE_DUMMY"].blank?
  required = %w[APP_HOST]
  missing = required.select { |name| ENV[name].blank? }
  raise "Missing required environment variables: #{missing.join(', ')}. See .env.example." if missing.any?

  # APP_HOST plus any extra names (comma separated), e.g. a hosting platform's deployment URL.
  hosts = [ ENV.fetch("APP_HOST"), *ENV.fetch("ADDITIONAL_HOSTS", "").split(",") ]
  hosts.map(&:strip).compact_blank.each { |host| Rails.application.config.hosts << host.split(":").first }
  Rails.application.config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
