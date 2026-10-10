class CreateReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :reviews do |t|
      t.references :movie, null: false, foreign_key: true, index: false
      t.string :user_name, null: false
      t.integer :stars, null: false
      t.text :comment

      t.timestamps

      t.check_constraint "stars BETWEEN 1 AND 5", name: "reviews_stars_range"
    end

    # One review per reviewer and movie, regardless of how the name is capitalized.
    add_index :reviews, "movie_id, lower(user_name)", unique: true, name: "index_reviews_on_movie_id_and_lower_user_name"
    # Newest-first review pages for a movie (also serves the foreign key).
    add_index :reviews, %i[movie_id id]
  end
end
