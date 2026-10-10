require "rails_helper"

# OpenAPI document for the API. Specs in spec/api describe each endpoint with
# the rswag DSL; running them checks every response against these schemas, and
# `bin/rails rswag:specs:swaggerize` writes the document to swagger/v1/openapi.yaml.
RSpec.configure do |config|
  config.openapi_root = Rails.root.join("swagger").to_s
  config.openapi_format = :yaml

  movie_properties = {
    id: { type: :integer, example: 2 },
    title: { type: :string, example: "Inception" },
    year: { type: :integer, example: 2010 },
    director: { type: :string, example: "Christopher Nolan" },
    average_stars: {
      type: :number, nullable: true, minimum: 1, maximum: 5, example: 2.75,
      description: "Average of all review stars, rounded to 2 decimals; null while the movie has no reviews"
    },
    reviews_count: { type: :integer, minimum: 0, example: 4 },
    actors: {
      type: :array, items: { type: :string },
      example: [ "Ellen Page", "Giovani Ribisi", "Joseph Gordon Levitt", "Leonardo Di Caprio" ],
      description: "Actor names, alphabetical"
    }
  }

  config.openapi_specs = {
    "v1/openapi.yaml" => {
      openapi: "3.0.3",
      info: {
        title: "Movies on Rails API",
        version: "v1",
        description: <<~TEXT
          Read-only access to the movie catalog.

          **Authentication.** Exchange an email address and password for a bearer token with
          `POST /api/v1/tokens`, then send `Authorization: Bearer <token>` with every other request.
          Tokens are valid for 30 days and can be revoked with `DELETE /api/v1/tokens`.

          **Rate limits.** 120 requests per minute per IP address, and 10 token requests per minute.
          Throttled requests get `429 Too Many Requests` with a `Retry-After` header.

          **Errors** are returned as `{"error": "..."}`.
        TEXT
      },
      servers: [ { url: "/", description: "This server" } ],
      security: [ { bearer: [] } ],
      components: {
        securitySchemes: {
          bearer: { type: :http, scheme: :bearer, description: "Token from POST /api/v1/tokens" }
        },
        schemas: {
          Movie: {
            type: :object, additionalProperties: false,
            required: movie_properties.keys.map(&:to_s),
            properties: movie_properties
          },
          MovieDetail: {
            type: :object, additionalProperties: false,
            required: (movie_properties.keys + %i[description locations]).map(&:to_s),
            properties: movie_properties.merge(
              description: { type: :string, nullable: true, example: "A thief who steals corporate secrets through the use of dream-sharing technology..." },
              locations: { type: :array, items: { "$ref" => "#/components/schemas/Location" }, description: "Filming locations, by country then name" }
            )
          },
          Location: {
            type: :object, additionalProperties: false, required: %w[name country],
            properties: {
              name: { type: :string, example: "BedfordShire" },
              country: { type: :string, example: "UK" }
            }
          },
          Review: {
            type: :object, additionalProperties: false, required: %w[id user_name stars comment created_at],
            properties: {
              id: { type: :integer, example: 9 },
              user_name: { type: :string, example: "Sam Pedro" },
              stars: { type: :integer, minimum: 1, maximum: 5, example: 2 },
              comment: { type: :string, nullable: true, example: "Empty" },
              created_at: { type: :string, format: "date-time", example: "2026-10-08T10:00:00.000Z" }
            }
          },
          PaginationMeta: {
            type: :object, additionalProperties: false, required: %w[current_page per_page total_pages total_count],
            properties: {
              current_page: { type: :integer, minimum: 1, example: 1 },
              per_page: { type: :integer, minimum: 1, maximum: Paginatable::MAX_PER_PAGE, example: Paginatable::DEFAULT_PER_PAGE },
              total_pages: { type: :integer, minimum: 1, example: 1 },
              total_count: { type: :integer, minimum: 0, example: 2 }
            }
          },
          MovieList: {
            type: :object, additionalProperties: false, required: %w[movies meta],
            properties: { movies: { type: :array, items: { "$ref" => "#/components/schemas/Movie" } }, meta: { "$ref" => "#/components/schemas/PaginationMeta" } }
          },
          MovieResponse: {
            type: :object, additionalProperties: false, required: %w[movie],
            properties: { movie: { "$ref" => "#/components/schemas/MovieDetail" } }
          },
          ReviewList: {
            type: :object, additionalProperties: false, required: %w[reviews meta],
            properties: { reviews: { type: :array, items: { "$ref" => "#/components/schemas/Review" } }, meta: { "$ref" => "#/components/schemas/PaginationMeta" } }
          },
          Credentials: {
            type: :object, additionalProperties: false, required: %w[email_address password],
            properties: {
              email_address: { type: :string, format: :email, example: "demo@example.com" },
              password: { type: :string, format: :password, example: "demo-password-123" }
            }
          },
          Token: {
            type: :object, additionalProperties: false, required: %w[token token_type expires_at],
            properties: {
              token: { type: :string, example: "q0dD3pXr8m5aW1nL7cT2vY9bK4sE6fH0jG3uZ8xN1oA", description: "Shown once; only a digest is stored" },
              token_type: { type: :string, enum: [ "Bearer" ], example: "Bearer" },
              expires_at: { type: :string, format: "date-time", example: "2026-11-07T10:00:00.000Z" }
            }
          },
          Error: {
            type: :object, additionalProperties: false, required: %w[error],
            properties: { error: { type: :string, example: "Not found" } }
          }
        }
      }
    }
  }
end
