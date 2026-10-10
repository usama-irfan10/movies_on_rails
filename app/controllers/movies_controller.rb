class MoviesController < ApplicationController
  include Paginatable

  def index
    @query = string_param(:actor).squish.first(Movie::MAX_SEARCH_LENGTH)
    @sort = Movie::SORT_OPTIONS.include?(params[:sort]) ? params[:sort] : Movie::DEFAULT_SORT

    scope = Movie.with_actor_matching(@query).sorted_by(@sort).includes(:actors, :locations)
    @movies, @pagination = paginate(scope)
  end

  private
    # Query params can arrive as arrays or hashes (?actor[]=x); treat those as blank.
    def string_param(key)
      params[key].is_a?(String) ? params[key] : ""
    end
end
