module Api
  module V1
    class ReviewsController < BaseController
      include Paginatable

      # GET /api/v1/movies/:movie_id/reviews?page=1&per_page=20 (newest first)
      def index
        movie = Movie.find(params[:movie_id])
        reviews, pagination = paginate(movie.reviews.newest_first, total_count: movie.reviews_count)

        render json: reviews, each_serializer: ReviewSerializer, root: "reviews", meta: pagination.to_meta
      end
    end
  end
end
