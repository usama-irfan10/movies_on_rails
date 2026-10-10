# One row per browser login. The signed cookie only stores this row's id.
class Session < ApplicationRecord
  MAX_AGE = 30.days

  belongs_to :user

  scope :active, -> { where(created_at: MAX_AGE.ago..) }
  scope :expired, -> { where(created_at: ...MAX_AGE.ago) }

  def self.prune_expired!
    expired.delete_all
  end
end
