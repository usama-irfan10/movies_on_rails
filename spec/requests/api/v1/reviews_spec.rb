require "rails_helper"

RSpec.describe "API v1 reviews", type: :request do
  let(:movie) { create(:movie) }
  let!(:older) { create(:review, movie:, user_name: "Sam", stars: 4, comment: "Good") }
  let!(:newer) { create(:review, movie:, user_name: "Pat", stars: 2, comment: nil) }

  it "returns the movie's reviews, newest first, with pagination metadata" do
    api_get "/api/v1/movies/#{movie.id}/reviews"

    expect(response).to have_http_status(:ok)
    expect(json["reviews"].pluck("user_name")).to eq([ "Pat", "Sam" ])
    expect(json["reviews"].last).to include("id" => older.id, "stars" => 4, "comment" => "Good", "created_at" => be_present)
    expect(json["meta"]).to eq("current_page" => 1, "per_page" => 20, "total_pages" => 1, "total_count" => 2)
  end

  it "only returns reviews of that movie" do
    create(:review, user_name: "Other")

    api_get "/api/v1/movies/#{movie.id}/reviews"

    expect(json["reviews"].pluck("user_name")).to contain_exactly("Pat", "Sam")
  end

  it "paginates" do
    api_get "/api/v1/movies/#{movie.id}/reviews", params: { per_page: 1, page: 2 }

    expect(json["reviews"].pluck("user_name")).to eq([ "Sam" ])
    expect(json["meta"]).to include("current_page" => 2, "total_pages" => 2)
  end

  it "uses the cached review count instead of counting" do
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { api_get "/api/v1/movies/#{movie.id}/reviews" }

    expect(queries.grep(/COUNT/i)).to be_empty
  end

  it "returns 404 for an unknown movie" do
    api_get "/api/v1/movies/0/reviews"

    expect(response).to have_http_status(:not_found)
    expect(json).to eq("error" => "Not found")
  end
end
