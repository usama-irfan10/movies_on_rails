# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_08_110002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "actors", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_actors_on_lower_name", unique: true
    t.index ["name"], name: "index_actors_on_name_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "locations", force: :cascade do |t|
    t.string "name", null: false
    t.string "country", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text), country", name: "index_locations_on_lower_name_and_country", unique: true
  end

  create_table "movie_actors", force: :cascade do |t|
    t.bigint "movie_id", null: false
    t.bigint "actor_id", null: false
    t.index ["actor_id"], name: "index_movie_actors_on_actor_id"
    t.index ["movie_id", "actor_id"], name: "index_movie_actors_on_movie_id_and_actor_id", unique: true
  end

  create_table "movie_locations", force: :cascade do |t|
    t.bigint "movie_id", null: false
    t.bigint "location_id", null: false
    t.index ["location_id"], name: "index_movie_locations_on_location_id"
    t.index ["movie_id", "location_id"], name: "index_movie_locations_on_movie_id_and_location_id", unique: true
  end

  create_table "movies", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.integer "year", null: false
    t.string "director", null: false
    t.decimal "average_stars", precision: 3, scale: 2
    t.integer "reviews_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((title)::text)", name: "index_movies_on_lower_title", unique: true
    t.index ["average_stars", "id"], name: "index_movies_on_rating_asc"
    t.index ["average_stars", "id"], name: "index_movies_on_rating_desc", order: { average_stars: "DESC NULLS LAST", id: :desc }
    t.check_constraint "average_stars >= 1::numeric AND average_stars <= 5::numeric", name: "movies_average_stars_range"
    t.check_constraint "reviews_count >= 0", name: "movies_reviews_count_non_negative"
    t.check_constraint "year >= 1888 AND year <= 2100", name: "movies_year_range"
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "movie_id", null: false
    t.string "user_name", null: false
    t.integer "stars", null: false
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "movie_id, lower((user_name)::text)", name: "index_reviews_on_movie_id_and_lower_user_name", unique: true
    t.index ["movie_id", "id"], name: "index_reviews_on_movie_id_and_id"
    t.check_constraint "stars >= 1 AND stars <= 5", name: "reviews_stars_range"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "movie_actors", "actors"
  add_foreign_key "movie_actors", "movies"
  add_foreign_key "movie_locations", "locations"
  add_foreign_key "movie_locations", "movies"
  add_foreign_key "reviews", "movies"
  add_foreign_key "sessions", "users"
end
