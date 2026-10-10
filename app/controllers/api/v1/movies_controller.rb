module Api
  module V1
    class MoviesController < BaseController
      include Paginatable

      # GET /api/v1/movies?actor=cage&sort=rating_desc&page=1&per_page=20
      def index
        scope = Movie.with_actor_matching(params[:actor]).sorted_by(params[:sort]).includes(:actors)
        movies, pagination = paginate(scope)

        render json: movies, each_serializer: MovieSerializer, root: "movies", meta: pagination.to_meta
      end

      # GET /api/v1/movies/:id
      def show
        movie = Movie.includes(:actors, :locations).find(params[:id])

        render json: movie, serializer: MovieDetailSerializer, root: "movie"
      end
    end
  end
end
