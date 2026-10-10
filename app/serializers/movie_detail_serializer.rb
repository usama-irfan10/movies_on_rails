# Full representation used by the show endpoint. Reviews are paginated
# separately at /api/v1/movies/:movie_id/reviews, so a popular movie cannot
# produce an unbounded response.
class MovieDetailSerializer < MovieSerializer
  attributes :description

  has_many :locations, serializer: LocationSerializer

  # Sorted in Ruby so the preloaded association is reused (no extra query).
  def locations
    object.locations.sort_by { |location| [ location.country, location.name ] }
  end
end
