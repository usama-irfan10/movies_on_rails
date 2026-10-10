# Compact representation used in lists.
class MovieSerializer < ActiveModel::Serializer
  attributes :id, :title, :year, :director, :average_stars, :reviews_count, :actors

  # A JSON number (or null while the movie has no reviews) rather than the
  # string Rails uses for decimals.
  def average_stars
    object.average_stars&.to_f
  end

  # Sorted in Ruby so the preloaded association is reused (no extra query).
  def actors
    object.actors.map(&:name).sort
  end
end
