class MovieLocation < ApplicationRecord
  belongs_to :movie
  belongs_to :location

  validates :location_id, uniqueness: { scope: :movie_id }
end
