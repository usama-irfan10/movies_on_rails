require "rails_helper"

RSpec.describe "API v1 movies", type: :request do
  let!(:top) do
    create(:movie, title: "Top Movie", actors: [ create(:actor, name: "Nicolas Cage"), create(:actor, name: "Ellen Page") ],
                   locations: [ create(:location, name: "Lone Pine", country: "US"), create(:location, name: "Bedford", country: "UK") ])
      .tap { |movie| create(:review, movie:, user_name: "Sam", stars: 5, comment: "The best ever!") }
  end
  let!(:low) do
    create(:movie, title: "Low Movie").tap { |movie| create(:review, movie:, stars: 1) }
  end

  describe "GET /api/v1/movies" do
    it "returns movies sorted by average stars with pagination metadata" do
      api_get "/api/v1/movies"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      expect(json["movies"].pluck("title")).to eq([ "Top Movie", "Low Movie" ])
      expect(json["meta"]).to eq("current_page" => 1, "per_page" => 20, "total_pages" => 1, "total_count" => 2)
    end

    it "serializes the compact movie representation" do
      api_get "/api/v1/movies"

      expect(json["movies"].first).to eq(
        "id" => top.id, "title" => "Top Movie", "year" => 2000, "director" => "Dana Director",
        "average_stars" => 5.0, "reviews_count" => 1, "actors" => [ "Ellen Page", "Nicolas Cage" ]
      )
    end

    it "returns null stars for unrated movies and lists them last" do
      create(:movie, title: "New Movie")

      api_get "/api/v1/movies", params: { sort: "rating_asc" }

      expect(json["movies"].pluck("title")).to eq([ "Low Movie", "Top Movie", "New Movie" ])
      expect(json["movies"].last).to include("average_stars" => nil, "reviews_count" => 0)
    end

    it "filters by actor" do
      api_get "/api/v1/movies", params: { actor: "cage" }

      expect(json["movies"].pluck("title")).to eq([ "Top Movie" ])
      expect(json["meta"]["total_count"]).to eq(1)
    end

    it "paginates and caps per_page" do
      api_get "/api/v1/movies", params: { per_page: 1, page: 2 }
      expect(json["movies"].pluck("title")).to eq([ "Low Movie" ])
      expect(json["meta"]).to include("current_page" => 2, "total_pages" => 2)

      api_get "/api/v1/movies", params: { per_page: 10_000 }
      expect(json["meta"]["per_page"]).to eq(Paginatable::MAX_PER_PAGE)
    end

    it "survives hostile pagination and sort params" do
      api_get "/api/v1/movies", params: { page: "99999999999999999999", per_page: [ "x" ], sort: { a: "b" }, actor: [ "c" ] }

      expect(response).to have_http_status(:ok)
      expect(json["movies"]).to be_empty
    end

    it "returns an empty list when nothing matches" do
      api_get "/api/v1/movies", params: { actor: "Nobody" }

      expect(json).to include("movies" => [], "meta" => include("total_count" => 0))
    end

    it "does not run a query per movie" do
      api_get "/api/v1/movies" # warm-up
      baseline = count_queries { api_get "/api/v1/movies" }

      create_list(:movie, 5, actors: [ create(:actor) ])

      expect(count_queries { api_get "/api/v1/movies" }).to eq(baseline)
    end
  end

  describe "GET /api/v1/movies/:id" do
    it "returns the movie with its locations" do
      api_get "/api/v1/movies/#{top.id}"

      expect(response).to have_http_status(:ok)
      expect(json["movie"]).to include(
        "title" => "Top Movie",
        "description" => "A film worth watching.",
        "locations" => [ { "name" => "Bedford", "country" => "UK" }, { "name" => "Lone Pine", "country" => "US" } ]
      )
      expect(json["movie"]).not_to have_key("reviews")
    end

    it "answers unknown API paths with a JSON 404" do
      [ "/api/v1/nope", "/api/v2/movies", "/api/v1/movies/1/unknown" ].each do |path|
        api_get path

        expect(response).to have_http_status(:not_found)
        expect(json).to eq("error" => "Not found")
      end
    end

    it "returns 404 with a JSON error for unknown or malformed ids" do
      [ "0", "abc", "99999999999999999999" ].each do |id|
        api_get "/api/v1/movies/#{id}"

        expect(response).to have_http_status(:not_found)
        expect(json).to eq("error" => "Not found")
      end
    end
  end
end
