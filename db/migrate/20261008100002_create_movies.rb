class CreateMovies < ActiveRecord::Migration[8.0]
  def change
    create_table :movies do |t|
      t.string :title, null: false
      t.text :description
      t.integer :year, null: false
      t.string :director, null: false
      # Cached rating stats, kept in sync by Movie.refresh_rating_stats! so that
      # sorting by rating is an indexed ORDER BY (no join or aggregate at read time).
      # average_stars is NULL while a movie has no reviews ("not rated", not "0 stars").
      t.decimal :average_stars, precision: 3, scale: 2
      t.integer :reviews_count, null: false, default: 0

      t.timestamps

      t.check_constraint "year BETWEEN 1888 AND 2100", name: "movies_year_range"
      t.check_constraint "average_stars BETWEEN 1 AND 5", name: "movies_average_stars_range"
      t.check_constraint "reviews_count >= 0", name: "movies_reviews_count_non_negative"
    end

    # Titles are unique regardless of case; the importer upserts against this index.
    add_index :movies, "lower(title)", unique: true, name: "index_movies_on_lower_title"
    # One index per rating sort direction, both with unrated movies last.
    add_index :movies, %i[average_stars id], order: { average_stars: "DESC NULLS LAST", id: :desc },
                                             name: "index_movies_on_rating_desc"
    add_index :movies, %i[average_stars id], name: "index_movies_on_rating_asc"
  end
end
