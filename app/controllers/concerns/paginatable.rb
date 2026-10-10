# Offset pagination with clamped, type-safe params (?page=2&per_page=50).
module Paginatable
  extend ActiveSupport::Concern

  DEFAULT_PER_PAGE = 20
  MAX_PER_PAGE = 100
  MAX_PAGE = 10_000 # bounds the OFFSET a client can ask for

  Pagination = Data.define(:page, :per_page, :total_count) do
    def total_pages = [ (total_count / per_page.to_f).ceil, 1 ].max
    def prev_page? = page > 1
    def next_page? = page < total_pages
    def out_of_range? = page > total_pages
    # per_page for links; nil (left out of the URL) when it is the default
    def per_page_param = (per_page unless per_page == DEFAULT_PER_PAGE)
    def to_meta = { current_page: page, per_page:, total_pages:, total_count: }
  end

  private
    # Returns [ records for the requested page, Pagination ]. Pass total_count
    # when it is already known (e.g. a counter cache) to skip the COUNT query.
    def paginate(scope, total_count: nil)
      pagination = Pagination.new(page: requested_page, per_page: requested_per_page, total_count: total_count || scope.count)
      records = scope.limit(pagination.per_page).offset((pagination.page - 1) * pagination.per_page)

      [ records, pagination ]
    end

    # `.to_s.to_i` keeps array or hash params (?page[]=1) from raising.
    def requested_page
      params[:page].to_s.to_i.clamp(1, MAX_PAGE)
    end

    def requested_per_page
      value = params[:per_page].to_s.to_i
      value.positive? ? [ value, MAX_PER_PAGE ].min : DEFAULT_PER_PAGE
    end
end
