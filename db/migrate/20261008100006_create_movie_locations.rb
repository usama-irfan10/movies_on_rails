class CreateMovieLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :movie_locations do |t|
      t.references :movie, null: false, foreign_key: true, index: false
      t.references :location, null: false, foreign_key: true
    end

    add_index :movie_locations, %i[movie_id location_id], unique: true
  end
end
