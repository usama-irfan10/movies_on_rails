class Movie < ApplicationRecord
  SORT_OPTIONS = %w[rating_desc rating_asc title].freeze
  DEFAULT_SORT = "rating_desc".freeze
  YEAR_RANGE = (1888..2100) # matches the movies_year_range check constraint
  MAX_SEARCH_LENGTH = 100

  # Join rows and reviews have no callbacks worth running when a movie goes away,
  # so they are removed with one DELETE each instead of one per record.
  has_many :movie_actors, dependent: :delete_all
  has_many :actors, through: :movie_actors
  has_many :movie_locations, dependent: :delete_all
  has_many :locations, through: :movie_locations
  has_many :reviews, dependent: :delete_all

  validates :title, presence: true, uniqueness: { case_sensitive: false }
  validates :director, presence: true
  validates :year, numericality: {
    only_integer: true, greater_than_or_equal_to: YEAR_RANGE.min, less_than_or_equal_to: YEAR_RANGE.max
  }

  # Orders by a whitelisted key; anything else falls back to the default, so user
  # input never reaches ORDER BY. Unrated movies come last in both rating orders,
  # and each order matches an index (see the create_movies migration).
  def self.sorted_by(key)
    case key.to_s
    when "rating_asc" then order(arel_table[:average_stars].asc.nulls_last, arel_table[:id].asc)
    when "title" then order(arel_table[:title].lower.asc)
    else order(arel_table[:average_stars].desc.nulls_last, arel_table[:id].desc)
    end
  end

  # Movies with at least one actor whose name contains the term (any case).
  # A subquery rather than a join returns each movie once, without DISTINCT.
  def self.with_actor_matching(term)
    term = term.to_s.squish.first(MAX_SEARCH_LENGTH)
    return all if term.empty?

    where(id: MovieActor.where(actor_id: Actor.matching(term).select(:id)).select(:movie_id))
  end

  # Recomputes reviews_count and average_stars from the reviews table in one
  # UPDATE. Pass ids to limit the refresh; omit them to refresh every movie.
  # The SQL is static - no user input is interpolated.
  def self.refresh_rating_stats!(ids = nil)
    relation = ids.nil? ? all : where(id: ids)
    relation.update_all(<<~SQL.squish)
      (reviews_count, average_stars) = (
        SELECT COUNT(*), ROUND(AVG(reviews.stars), 2) FROM reviews WHERE reviews.movie_id = movies.id
      )
    SQL
  end

  def rated?
    reviews_count.positive?
  end
end
