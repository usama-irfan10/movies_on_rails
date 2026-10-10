require "swagger_helper"

RSpec.describe "API v1: reviews", type: :request do
  let(:Authorization) { "Bearer #{ApiToken.issue_for(create(:user)).plaintext}" }
  let(:movie) { create(:movie) }

  before do
    create(:review, movie:, user_name: "Mack Boe", stars: 4, comment: "Ok movie")
    create(:review, movie:, user_name: "Sam Pedro", stars: 2, comment: "Empty")
  end

  path "/api/v1/movies/{movie_id}/reviews" do
    parameter name: :movie_id, in: :path, required: true, schema: { type: :integer }

    get "List a movie's reviews" do
      tags "Reviews"
      description "Paginated reviews of one movie, newest first."
      operationId "listMovieReviews"
      produces "application/json"
      parameter name: :page, in: :query, required: false, schema: { type: :integer, minimum: 1, default: 1 }
      parameter name: :per_page, in: :query, required: false,
                schema: { type: :integer, minimum: 1, maximum: Paginatable::MAX_PER_PAGE, default: Paginatable::DEFAULT_PER_PAGE }

      response "200", "A page of reviews" do
        schema "$ref" => "#/components/schemas/ReviewList"
        let(:movie_id) { movie.id }

        run_test! do
          expect(response.parsed_body["reviews"].pluck("user_name")).to eq([ "Sam Pedro", "Mack Boe" ])
        end
      end

      response "404", "No movie with this id" do
        schema "$ref" => "#/components/schemas/Error"
        let(:movie_id) { 0 }

        run_test!
      end

      response "401", "Missing, invalid or expired token" do
        schema "$ref" => "#/components/schemas/Error"
        let(:movie_id) { movie.id }
        let(:Authorization) { "Bearer not-a-token" }

        run_test!
      end
    end
  end
end
