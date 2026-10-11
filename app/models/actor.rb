class Actor < ApplicationRecord
  has_many :movie_actors, dependent: :delete_all
  has_many :movies, through: :movie_actors

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  # Partial, case-insensitive match. LIKE wildcards in the input are escaped
  # so "%" and "_" are matched literally.
  scope :matching, ->(term) { where("actors.name ILIKE ?", "%#{sanitize_sql_like(term.to_s.squish)}%") }
end
