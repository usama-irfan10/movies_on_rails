class User < ApplicationRecord
  MIN_PASSWORD_LENGTH = 12

  has_secure_password
  has_many :sessions, dependent: :delete_all
  has_many :api_tokens, dependent: :delete_all

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: MIN_PASSWORD_LENGTH }, allow_nil: true

  after_update :revoke_credentials, if: :saved_change_to_password_digest?

  private
    # A changed password (for example after a reset) invalidates existing logins and API tokens.
    def revoke_credentials
      sessions.delete_all
      api_tokens.delete_all
    end
end
