# Bearer token for API clients. Only a SHA-256 digest is stored, so a database
# leak does not expose usable tokens. Tokens are 256 bits of randomness, which
# is why a fast digest (rather than bcrypt) is the right tool here.
class ApiToken < ApplicationRecord
  DEFAULT_TTL = 30.days
  USAGE_TOUCH_INTERVAL = 1.hour

  belongs_to :user

  validates :name, :token_digest, :expires_at, presence: true
  validates :token_digest, uniqueness: true

  scope :active, -> { where(expires_at: Time.current..) }
  scope :expired, -> { where(expires_at: ...Time.current) }

  def self.prune_expired!
    expired.delete_all
  end

  # The plaintext exists only on the instance returned by .issue_for - show it once.
  attr_accessor :plaintext

  def self.issue_for(user, name: "API token", ttl: DEFAULT_TTL)
    plaintext = SecureRandom.urlsafe_base64(32)
    token = create!(user:, name:, token_digest: digest(plaintext), expires_at: ttl.from_now)
    token.plaintext = plaintext
    token
  end

  def self.find_active_by_plaintext(plaintext)
    return if plaintext.blank?

    active.find_by(token_digest: digest(plaintext))
  end

  def self.digest(plaintext)
    OpenSSL::Digest::SHA256.hexdigest(plaintext)
  end

  # Records usage for auditing, at most once per interval to avoid a write on every request.
  def record_usage!
    touch(:last_used_at) if last_used_at.nil? || last_used_at < USAGE_TOUCH_INTERVAL.ago
  end
end
