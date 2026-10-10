class Review < ApplicationRecord
  STARS_RANGE = (1..5) # matches the reviews_stars_range check constraint

  belongs_to :movie

  validates :user_name, presence: true, uniqueness: { scope: :movie_id, case_sensitive: false }
  validates :stars, inclusion: { in: STARS_RANGE }

  scope :newest_first, -> { order(id: :desc) }

  after_commit :refresh_movie_rating_stats

  private
    # Runs after commit so concurrent writers cannot leave stale stats behind:
    # each refresh recomputes from committed rows. When a review moves to another
    # movie, both movies are refreshed.
    def refresh_movie_rating_stats
      movie_ids = [ movie_id, movie_id_previously_was ].compact.uniq
      Movie.refresh_rating_stats!(movie_ids)
    end
end
