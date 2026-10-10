# Mail settings (used for password reset emails).
#   development: letter_opener opens each message in the browser (no SMTP needed).
#                Inside Docker there is no browser to open, so emails are listed
#                at http://localhost:3000/letter_opener instead.
#   test:        messages are collected in memory
#   production:  delivery is intentionally not configured here - add it when you deploy
Rails.application.configure do
  config.action_mailer.default_url_options = {
    host: ENV.fetch("APP_HOST", "localhost:3000"),
    protocol: Rails.env.production? ? "https" : "http"
  }
  config.action_mailer.perform_caching = false
  config.action_mailer.raise_delivery_errors = true

  if Rails.env.test?
    config.action_mailer.delivery_method = :test
  elsif Rails.env.development?
    config.action_mailer.delivery_method = ENV["DOCKER"].present? ? :letter_opener_web : :letter_opener
    config.action_mailer.perform_deliveries = true
  end
end
