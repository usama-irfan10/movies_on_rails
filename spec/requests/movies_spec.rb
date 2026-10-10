require "rails_helper"

RSpec.describe "Movies overview", type: :request do
  let!(:alpha) do
    create(:movie, title: "Alpha Film", actors: [ create(:actor, name: "Nicolas Cage") ], locations: [ create(:location, name: "Lone Pine") ])
      .tap { |movie| create(:review, movie:, stars: 5) }
  end
  let!(:beta) do
    create(:movie, title: "Beta Film", actors: [ create(:actor, name: "Ellen Page") ])
      .tap { |movie| create(:review, movie:, stars: 2) }
  end

  def titles_in_order
    response.body.scan(/(?:Alpha|Beta|Gamma) Film/).uniq
  end

  it "lists movies with cast, locations and rating, best rated first" do
    get movies_path

    expect(response).to have_http_status(:ok)
    expect(titles_in_order).to eq([ "Alpha Film", "Beta Film" ])
    expect(response.body).to include("Nicolas Cage", "Lone Pine (US)", "5.00 stars from 1 review")
  end

  it "lists unrated movies last and says they have no reviews" do
    create(:movie, title: "Gamma Film")

    get movies_path, params: { sort: "rating_asc" }

    expect(titles_in_order).to eq([ "Beta Film", "Alpha Film", "Gamma Film" ])
    expect(response.body).to include("No reviews yet")
  end

  it "falls back to the default sort for unknown values" do
    get movies_path, params: { sort: "bogus; DROP TABLE movies" }

    expect(response).to have_http_status(:ok)
    expect(titles_in_order).to eq([ "Alpha Film", "Beta Film" ])
  end

  it "filters by actor name, partially and case-insensitively" do
    get movies_path, params: { actor: "cAgE" }

    expect(titles_in_order).to eq([ "Alpha Film" ])
    expect(response.body).to include("1 movie")
  end

  it "explains when no actor matches" do
    get movies_path, params: { actor: "Nobody" }

    expect(response.body).to include("No movies with an actor matching")
  end

  it "labels the search box as an actor search" do
    get movies_path

    expect(response.body).to include(">Actor name</label>")
  end

  it "treats wildcard characters in the search literally" do
    get movies_path, params: { actor: "%" }

    expect(titles_in_order).to be_empty
  end

  it "escapes the search term" do
    get movies_path, params: { actor: "<script>alert(1)</script>" }

    expect(response.body).not_to include("<script>alert(1)</script>")
    expect(response.body).to include("&lt;script&gt;")
  end

  it "paginates" do
    stub_const("Paginatable::DEFAULT_PER_PAGE", 1)

    get movies_path, params: { page: 2 }

    expect(titles_in_order).to eq([ "Beta Film" ])
    expect(response.body).to include("Page 2 of 2")
  end

  it "keeps a custom page size in the pagination links" do
    get movies_path, params: { per_page: 1, sort: "title" }

    next_link = Nokogiri::HTML(response.body).at_css("a[rel=next]")["href"]
    expect(next_link).to include("per_page=1", "sort=title", "page=2")

    get next_link
    expect(titles_in_order).to eq([ "Beta Film" ])
  end

  it "explains a page past the end instead of claiming there are no movies" do
    get movies_path, params: { page: 5 }

    expect(response.body).to include("There is no page 5")
    expect(response.body).not_to include("No movies yet")
  end

  it "tolerates malformed params, ignoring non-text values" do
    get movies_path, params: { page: [ "1" ], per_page: { a: "b" }, actor: [ "x" ], sort: { b: "c" } }

    expect(response).to have_http_status(:ok)
    expect(titles_in_order).to eq([ "Alpha Film", "Beta Film" ])
    expect(response.body).not_to include("[&quot;x&quot;]")
  end

  it "loads the page with a fixed number of queries, however many movies are shown" do
    count_queries = lambda do
      queries = 0
      callback = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { get movies_path }
      queries
    end

    baseline = count_queries.call
    create_list(:movie, 3, actors: [ create(:actor) ], locations: [ create(:location) ])

    expect(count_queries.call).to eq(baseline)
  end
end
