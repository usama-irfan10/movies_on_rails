class Location < ApplicationRecord
  has_many :movie_locations, dependent: :delete_all
  has_many :movies, through: :movie_locations

  normalizes :country, with: ->(country) { country.strip.upcase }

  validates :name, presence: true, uniqueness: { scope: :country, case_sensitive: false }
  validates :country, presence: true

  def to_s
    "#{name} (#{country})"
  end
end
