# Mail settings (used for password reset emails).
#   development: letter_opener opens each message in the browser (no SMTP needed).
#                Inside Docker there is no browser to open, so emails are listed
#                at http://localhost:3000/letter_opener instead.
#   test:        messages are collected in memory
#   production:  no real email delivery is configured. Demo deployments can keep
#                emails in a web inbox at /letter_opener, protected by HTTP basic
#                auth, by setting MAIL_INBOX_USERNAME and MAIL_INBOX_PASSWORD.
#                Without them, emails are not sent. Use SMTP or an email API for real mail.
module MailInbox
  # Whether the /letter_opener web inbox is mounted (see config/routes.rb).
  def self.enabled?
    Rails.env.development? || (Rails.env.production? && credentials.present?)
  end

  # Basic auth credentials for the production inbox, or nil when not configured.
  def self.credentials
    username, password = ENV.values_at("MAIL_INBOX_USERNAME", "MAIL_INBOX_PASSWORD")
    { name: username, password: password } if username.present? && password.present?
  end
end

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
  elsif Rails.env.production?
    config.action_mailer.delivery_method = :letter_opener_web if MailInbox.enabled?
    config.action_mailer.perform_deliveries = MailInbox.enabled?
  end

  # Lock the production inbox behind basic auth. Its pages use inline scripts and
  # styles, so the app-wide Content-Security-Policy is switched off for them only.
  config.to_prepare do
    if Rails.env.production? && MailInbox.enabled?
      LetterOpenerWeb::ApplicationController.http_basic_authenticate_with(**MailInbox.credentials, realm: "Mail inbox")
      LetterOpenerWeb::ApplicationController.content_security_policy(false)
    end
  end
end
