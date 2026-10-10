# Imports movies.csv and reviews.csv into the normalized schema.
#
# Parsing lives in MoviesFile and ReviewsFile (plain Ruby); this class writes the
# result with batched upserts inside one transaction, so an import either fully
# succeeds or changes nothing.
#
# Re-running is safe: rows are matched on case-insensitive natural keys (movie
# title, actor name, location name and country, reviewer per movie), so existing
# rows are updated rather than duplicated. Rows missing from the files are kept.
#
# movies.csv is collapsed in memory (one entry per unique movie, actor and
# location); reviews.csv is streamed in batches, so its size does not matter.
class MovieCatalogImporter
  BATCH_SIZE = 1_000
  # Concurrent imports wait for each other instead of racing on the same rows.
  # The number is an arbitrary application-wide lock key.
  LOCK_SQL = "SELECT pg_advisory_xact_lock(4201003)".freeze

  InvalidFile = Class.new(StandardError)
  Summary = Data.define(:movies, :actors, :locations, :reviews, :issues)

  def self.call(...)
    new(...).call
  end

  def initialize(movies_path:, reviews_path:)
    @issues = Issues.new
    @movies_file = MoviesFile.new(movies_path, issues: @issues, year_range: Movie::YEAR_RANGE)
    @reviews_file = ReviewsFile.new(reviews_path, issues: @issues, stars_range: Review::STARS_RANGE)
  end

  def call
    catalog = @movies_file.read # parsed before the transaction to keep it short

    ApplicationRecord.transaction do
      ApplicationRecord.with_connection { |connection| connection.execute(LOCK_SQL) }

      movie_ids = persist_catalog(catalog)
      reviews = persist_reviews(movie_ids)

      Summary.new(
        movies: catalog.movies.size,
        actors: catalog.actors.size,
        locations: catalog.locations.size,
        reviews:,
        issues: @issues
      )
    end
  end

  private
    # Upserts movies, actors and locations, links them, and returns
    # { lowercased title => movie id } for matching reviews.
    def persist_catalog(catalog)
      movie_ids = upsert(Movie, catalog.movies.values, unique_by: :index_movies_on_lower_title,
                                                       returning: %w[id title]) { |row| row["title"].downcase }
      actor_ids = upsert(Actor, catalog.actors.values.map { |name| { name: } }, unique_by: :index_actors_on_lower_name,
                                                                                returning: %w[id name]) { |row| row["name"].downcase }
      location_ids = upsert(Location, catalog.locations.values, unique_by: :index_locations_on_lower_name_and_country,
                                                                returning: %w[id name country]) { |row| [ row["name"].downcase, row["country"] ] }

      link(MovieActor, catalog.movie_actors, unique_by: %i[movie_id actor_id]) do |movie_key, actor_key|
        { movie_id: movie_ids.fetch(movie_key), actor_id: actor_ids.fetch(actor_key) }
      end
      link(MovieLocation, catalog.movie_locations, unique_by: %i[movie_id location_id]) do |movie_key, location_key|
        { movie_id: movie_ids.fetch(movie_key), location_id: location_ids.fetch(location_key) }
      end

      movie_ids
    end

    # Writes rows in batches and returns { key => id }, read from RETURNING so
    # no second query is needed to look the ids up.
    def upsert(model, rows, unique_by:, returning:, &key)
      rows.each_slice(BATCH_SIZE).with_object({}) do |batch, ids|
        model.upsert_all(batch, unique_by:, returning:).each { |row| ids[key.call(row)] = row["id"] }
      end
    end

    # Inserts join rows; links that already exist are left alone.
    def link(model, pairs, unique_by:, &build)
      pairs.each_slice(BATCH_SIZE) { |batch| model.insert_all(batch.map(&build), unique_by:) }
    end

    # Streams reviews in batches. The last row for a reviewer and movie wins, both
    # within a batch (deduplicated here) and across batches (the later upsert
    # overwrites). Refreshes the rating stats of every movie it touched and
    # returns the number of review rows written.
    def persist_reviews(movie_ids)
      written = 0
      touched_movie_ids = Set.new

      @reviews_file.each_batch(BATCH_SIZE) do |reviews|
        load_existing_movie_ids(movie_ids, reviews)
        rows = review_rows(reviews, movie_ids)
        next if rows.empty?

        Review.upsert_all(rows, unique_by: :index_reviews_on_movie_id_and_lower_user_name)
        written += rows.size
        touched_movie_ids.merge(rows.map { |row| row[:movie_id] })
      end

      touched_movie_ids.each_slice(BATCH_SIZE) { |ids| Movie.refresh_rating_stats!(ids) }
      written
    end

    # Reviews may belong to movies imported earlier rather than in this run.
    # Looks those up with one indexed query per batch; misses are remembered
    # (as nil) so later batches don't ask again.
    def load_existing_movie_ids(movie_ids, reviews)
      missing = reviews.map { |review| review[:title].downcase }.uniq.reject { |key| movie_ids.key?(key) }
      return if missing.empty?

      Movie.where(Movie.arel_table[:title].lower.in(missing)).pluck(:title, :id).each do |title, id|
        movie_ids[title.downcase] = id
      end
      missing.each { |key| movie_ids[key] ||= nil }
    end

    def review_rows(reviews, movie_ids)
      reviews.each_with_object({}) do |review, rows|
        movie_id = movie_ids[review[:title].downcase]

        if movie_id
          rows[[ movie_id, review[:user_name].downcase ]] = { movie_id:, **review.slice(:user_name, :stars, :comment) }
        else
          @issues.add(@reviews_file.name, review[:line], "unknown movie #{review[:title].inspect}")
        end
      end.values
    end
end
