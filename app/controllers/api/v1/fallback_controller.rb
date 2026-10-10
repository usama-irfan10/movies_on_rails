module Api
  module V1
    # Answers unknown /api/... paths with the API's JSON 404 instead of Rails' HTML page.
    class FallbackController < BaseController
      def show
        not_found
      end
    end
  end
end
