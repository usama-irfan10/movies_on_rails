require "swagger_helper"

RSpec.describe "API v1: movies", type: :request do
  let(:Authorization) { "Bearer #{ApiToken.issue_for(create(:user)).plaintext}" }
  let!(:inception) do
    create(:movie, title: "Inception", year: 2010, director: "Christopher Nolan",
                   actors: [ create(:actor, name: "Leonardo Di Caprio"), create(:actor, name: "Ellen Page") ],
                   locations: [ create(:location, name: "BedfordShire", country: "UK") ])
      .tap { |movie| create(:review, movie:, stars: 3) }
  end
  let!(:gone) do
    create(:movie, title: "Gone in 60 seconds", year: 2000, director: "Dominic Sena",
                   actors: [ create(:actor, name: "Nicolas Cage") ])
      .tap { |movie| create(:review, movie:, stars: 4) }
  end

  path "/api/v1/movies" do
    get "List movies" do
      tags "Movies"
      description "Paginated movies, best rated first by default. Movies without reviews come last in both rating orders."
      operationId "listMovies"
      produces "application/json"
      parameter name: :actor, in: :query, required: false,
                description: "Only movies with an actor whose name contains this text (case-insensitive)",
                schema: { type: :string, maxLength: Movie::MAX_SEARCH_LENGTH }
      parameter name: :sort, in: :query, required: false,
                description: "Unknown values fall back to rating_desc",
                schema: { type: :string, enum: Movie::SORT_OPTIONS, default: Movie::DEFAULT_SORT }
      parameter name: :page, in: :query, required: false, schema: { type: :integer, minimum: 1, default: 1 }
      parameter name: :per_page, in: :query, required: false,
                schema: { type: :integer, minimum: 1, maximum: Paginatable::MAX_PER_PAGE, default: Paginatable::DEFAULT_PER_PAGE }

      response "200", "A page of movies" do
        schema "$ref" => "#/components/schemas/MovieList"

        run_test! do
          expect(response.parsed_body["movies"].pluck("title")).to eq([ "Gone in 60 seconds", "Inception" ])
        end
      end

      response "200", "A page of movies" do # filtered and sorted
        schema "$ref" => "#/components/schemas/MovieList"
        let(:actor) { "leo" }
        let(:sort) { "title" }
        let(:per_page) { 10 }

        run_test! do
          expect(response.parsed_body["movies"].pluck("title")).to eq([ "Inception" ])
        end
      end

      response "401", "Missing, invalid or expired token" do
        schema "$ref" => "#/components/schemas/Error"
        let(:Authorization) { "Bearer not-a-token" }

        run_test!
      end
    end
  end

  path "/api/v1/movies/{id}" do
    parameter name: :id, in: :path, required: true, schema: { type: :integer }

    get "Show a movie" do
      tags "Movies"
      description "One movie with its filming locations. Reviews are listed at /api/v1/movies/{id}/reviews."
      operationId "getMovie"
      produces "application/json"

      response "200", "The movie" do
        schema "$ref" => "#/components/schemas/MovieResponse"
        let(:id) { inception.id }

        run_test! do
          expect(response.parsed_body.dig("movie", "locations")).to eq([ { "name" => "BedfordShire", "country" => "UK" } ])
        end
      end

      response "404", "No movie with this id" do
        schema "$ref" => "#/components/schemas/Error"
        let(:id) { 0 }

        run_test!
      end

      response "401", "Missing, invalid or expired token" do
        schema "$ref" => "#/components/schemas/Error"
        let(:id) { inception.id }
        let(:Authorization) { "Bearer not-a-token" }

        run_test!
      end
    end
  end
end
