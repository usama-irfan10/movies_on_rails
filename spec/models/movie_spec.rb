require "rails_helper"

RSpec.describe Movie do
  describe "associations" do
    it { is_expected.to have_many(:actors).through(:movie_actors) }
    it { is_expected.to have_many(:locations).through(:movie_locations) }
    it { is_expected.to have_many(:reviews).dependent(:delete_all) }
  end

  describe "validations" do
    subject { build(:movie) }

    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_uniqueness_of(:title).case_insensitive }
    it { is_expected.to validate_presence_of(:director) }

    it do
      is_expected.to validate_numericality_of(:year).only_integer
        .is_greater_than_or_equal_to(1888).is_less_than_or_equal_to(2100)
    end
  end

  describe "database constraints" do
    it "rejects case-insensitive duplicate titles" do
      create(:movie, title: "Inception")

      expect { build(:movie, title: "INCEPTION").save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "rejects years outside the supported range" do
      expect { build(:movie, year: 1500).save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /movies_year_range/)
    end
  end

  describe ".sorted_by" do
    let!(:best) { create(:movie, title: "best").tap { |movie| create(:review, movie:, stars: 5) } }
    let!(:worst) { create(:movie, title: "Worst").tap { |movie| create(:review, movie:, stars: 1) } }
    let!(:unrated) { create(:movie, title: "Unrated") }

    it "sorts by average stars, highest first, by default" do
      expect(described_class.sorted_by(nil).to_a).to eq([ best, worst, unrated ])
    end

    it "sorts by average stars, lowest first, still listing unrated movies last" do
      expect(described_class.sorted_by("rating_asc").to_a).to eq([ worst, best, unrated ])
    end

    it "breaks rating ties by id so pages are stable" do
      tie = create(:movie).tap { |movie| create(:review, movie:, stars: 5) }

      expect(described_class.sorted_by("rating_desc").first(2)).to eq([ tie, best ])
      expect(described_class.sorted_by("rating_asc").last(3)).to eq([ best, tie, unrated ])
    end

    it "sorts by title, ignoring case" do
      expect(described_class.sorted_by("title").to_a).to eq([ best, unrated, worst ])
    end

    it "ignores unknown sort keys instead of passing them to SQL" do
      expect(described_class.sorted_by("id; DROP TABLE movies").to_a).to eq([ best, worst, unrated ])
      expect(described_class.sorted_by([ "title" ]).to_a).to eq([ best, worst, unrated ])
    end
  end

  describe ".with_actor_matching" do
    let!(:cage_movie) { create(:movie, actors: [ create(:actor, name: "Nicolas Cage"), create(:actor, name: "Nicolas Sage") ]) }
    let!(:other_movie) { create(:movie, actors: [ create(:actor, name: "Ellen Page") ]) }

    it "matches partially and case-insensitively" do
      expect(described_class.with_actor_matching("cAgE")).to contain_exactly(cage_movie)
    end

    it "normalizes whitespace in the search term" do
      expect(described_class.with_actor_matching("  nicolas   cage ")).to contain_exactly(cage_movie)
    end

    it "returns a movie once even when several actors match" do
      expect(described_class.with_actor_matching("nicolas").to_a).to eq([ cage_movie ])
    end

    it "returns everything for a blank term" do
      expect(described_class.with_actor_matching("  ")).to contain_exactly(cage_movie, other_movie)
      expect(described_class.with_actor_matching(nil)).to contain_exactly(cage_movie, other_movie)
    end

    it "returns nothing when no actor matches, including over-long terms" do
      expect(described_class.with_actor_matching("Nobody")).to be_empty
      expect(described_class.with_actor_matching("a" * 10_000)).to be_empty
    end

    it "combines with sorting and the result count" do
      relation = described_class.with_actor_matching("nicolas").sorted_by("rating_desc")

      expect(relation.count).to eq(1)
    end

    it "combines with every sort order, including the title order" do
      Movie::SORT_OPTIONS.each do |sort|
        expect(described_class.with_actor_matching("nicolas").sorted_by(sort).to_a).to eq([ cage_movie ])
      end
    end
  end

  describe ".refresh_rating_stats!" do
    it "recalculates the count and the rounded average from reviews" do
      movie = create(:movie)
      create(:review, movie:, stars: 4)
      create(:review, movie:, stars: 5)
      create(:review, movie:, stars: 5)
      movie.update_columns(average_stars: nil, reviews_count: 0)

      described_class.refresh_rating_stats!

      expect(movie.reload).to have_attributes(average_stars: BigDecimal("4.67"), reviews_count: 3)
    end

    it "clears the average when a movie has no reviews" do
      movie = create(:movie)
      movie.update_columns(average_stars: 3, reviews_count: 2)

      described_class.refresh_rating_stats!([ movie.id ])

      expect(movie.reload).to have_attributes(average_stars: nil, reviews_count: 0)
    end

    it "only touches the given movies" do
      touched = create(:movie)
      untouched = create(:movie)
      create(:review, movie: untouched, stars: 5)
      untouched.update_columns(average_stars: nil, reviews_count: 0)

      described_class.refresh_rating_stats!([ touched.id ])

      expect(untouched.reload.reviews_count).to eq(0)
    end
  end

  describe "#destroy" do
    it "removes the movie's reviews and links but keeps shared actors and locations" do
      actor = create(:actor)
      location = create(:location)
      movie = create(:movie, actors: [ actor ], locations: [ location ])
      create(:review, movie:)

      movie.destroy!

      expect([ Review.count, MovieActor.count, MovieLocation.count ]).to eq([ 0, 0, 0 ])
      expect(actor.reload).to be_persisted
      expect(location.reload).to be_persisted
    end
  end
end
