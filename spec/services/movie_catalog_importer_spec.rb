require "rails_helper"

RSpec.describe MovieCatalogImporter do
  subject(:import) { described_class.call(movies_path:, reviews_path:) }

  let(:movies_path) { file_fixture("movies.csv") }
  let(:reviews_path) { file_fixture("reviews.csv") }

  def counts
    [ Movie, Actor, Location, MovieActor, MovieLocation, Review ].map(&:count)
  end

  describe "movies.csv" do
    before { import }

    it "collapses the denormalized rows into unique movies, actors and locations" do
      expect(Movie.pluck(:title)).to contain_exactly("Heist", "Voyage", "Lonely")
      expect(Actor.pluck(:name)).to contain_exactly("Alice Star", "Bob Actor")
      expect(Location.pluck(:name, :country)).to contain_exactly(%w[Paris FR], %w[Berlin DE])
    end

    it "links movies to their actors and filming locations" do
      heist = Movie.find_by!(title: "Heist")

      expect(heist.actors.pluck(:name)).to contain_exactly("Alice Star", "Bob Actor")
      expect(heist.locations.pluck(:name)).to contain_exactly("Paris", "Berlin")
      expect([ MovieActor.count, MovieLocation.count ]).to eq([ 4, 3 ])
    end

    it "keeps the first values when rows for the same movie disagree" do
      expect(Movie.find_by!(title: "Voyage")).to have_attributes(year: 2010, description: "A ship sails.")
    end
  end

  describe "reviews.csv" do
    before { import }

    it "keeps the last review per reviewer and movie, ignoring case" do
      heist = Movie.find_by!(title: "Heist")

      expect(heist.reviews.pluck(:user_name, :stars)).to contain_exactly([ "SAM", 4 ], [ "Pat", 3 ])
      expect(Review.count).to eq(4)
    end

    it "stores a blank review text as nil" do
      expect(Movie.find_by!(title: "Voyage").reviews.sole.comment).to be_nil
    end

    it "caches the rating stats on each movie" do
      expect(Movie.find_by!(title: "Heist")).to have_attributes(average_stars: BigDecimal("3.5"), reviews_count: 2)
      expect(Movie.find_by!(title: "Lonely")).to have_attributes(average_stars: BigDecimal("4"), reviews_count: 1)
    end
  end

  it "reports every row it skipped or could not reconcile" do
    expect(import.issues.messages).to contain_exactly(
      'movies.csv line 7: conflicting details for "Voyage" (kept the values from line 6)',
      'movies.csv line 8: invalid year "not-a-year" for "Broken"',
      'movies.csv line 9: invalid year "1500" for "Ancient"',
      'movies.csv line 10: filming location "Rome" has no country',
      'reviews.csv line 6: unknown movie "Ghost"',
      'reviews.csv line 7: stars must be a whole number from 1 to 5, got "9"',
      "reviews.csv line 8: missing user",
      'reviews.csv line 9: stars must be a whole number from 1 to 5, got "4.5"'
    )
    expect(import).to have_attributes(movies: 3, actors: 2, locations: 2, reviews: 4)
  end

  describe "re-running" do
    it "is idempotent" do
      described_class.call(movies_path:, reviews_path:)

      expect { described_class.call(movies_path:, reviews_path:) }.not_to change { counts }
    end

    it "updates changed reviews and their movie's rating" do
      described_class.call(movies_path:, reviews_path:)
      changed = write_csv("reviews.csv", "Movie,User,Stars,Review\nHeist,Pat,5,Grew on me\n")

      described_class.call(movies_path:, reviews_path: changed)

      expect(Movie.find_by!(title: "Heist")).to have_attributes(average_stars: BigDecimal("4.5"), reviews_count: 2)
    end

    it "matches existing records ignoring case instead of duplicating them" do
      create(:actor, name: "alice star")

      expect { import }.to change(Actor, :count).by(1) # only Bob Actor is new
      expect(Actor.where("lower(name) = ?", "alice star").pluck(:name)).to eq([ "Alice Star" ])
    end

    it "attaches reviews to movies imported earlier" do
      described_class.call(movies_path:, reviews_path:)
      no_movies = write_csv("movies.csv", "Movie,Description,Year,Director,Actor,Filming location,Country\n")
      reviews = write_csv("reviews.csv", "Movie,User,Stars,Review\nVOYAGE,New Reviewer,4,Late review\n")

      described_class.call(movies_path: no_movies, reviews_path: reviews)

      expect(Movie.find_by!(title: "Voyage")).to have_attributes(average_stars: BigDecimal("3"), reviews_count: 2)
    end
  end

  it "gives the same result when the files are processed in many small batches" do
    stub_const("MovieCatalogImporter::BATCH_SIZE", 2)

    import

    expect(counts).to eq([ 3, 2, 2, 4, 3, 4 ])
    expect(Movie.find_by!(title: "Heist").reviews.pluck(:user_name, :stars)).to contain_exactly([ "SAM", 4 ], [ "Pat", 3 ])
  end

  describe "invalid files" do
    it "rejects a file without the expected columns and changes nothing" do
      wrong = write_csv("movies.csv", "Title,Year\nHeist,2001\n")

      expect { described_class.call(movies_path: wrong, reviews_path:) }
        .to raise_error(described_class::InvalidFile, /movies.csv: missing column\(s\) movie, description, director/)
      expect(counts).to all(be_zero)
    end

    it "rolls back everything when the reviews file turns out to be malformed" do
      malformed = write_csv("reviews.csv", "Movie,User,Stars,Review\nHeist,\"Sam,5,Great\n")

      expect { described_class.call(movies_path:, reviews_path: malformed) }
        .to raise_error(described_class::InvalidFile, /reviews.csv: Unclosed quoted field/)
      expect(counts).to all(be_zero)
    end

    it "reports a missing file" do
      expect { described_class.call(movies_path: "nope.csv", reviews_path:) }
        .to raise_error(described_class::InvalidFile, "nope.csv: file not found")
    end
  end

  it "imports the bundled data files" do
    summary = described_class.call(
      movies_path: Rails.root.join("db/data/movies.csv"),
      reviews_path: Rails.root.join("db/data/reviews.csv")
    )

    expect(summary).to have_attributes(movies: 2, actors: 5, locations: 3, reviews: 9)
    expect(summary.issues.count).to eq(0)
    expect(Movie.sorted_by("rating_desc").pluck(:title, :average_stars)).to eq(
      [ [ "Gone in 60 seconds", BigDecimal("3.6") ], [ "Inception", BigDecimal("2.75") ] ]
    )
  end
end
