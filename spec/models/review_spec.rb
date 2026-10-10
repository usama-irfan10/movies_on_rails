require "rails_helper"

RSpec.describe Review do
  describe "validations" do
    subject { build(:review) }

    it { is_expected.to belong_to(:movie) }
    it { is_expected.to validate_presence_of(:user_name) }
    it { is_expected.to validate_inclusion_of(:stars).in_range(1..5) }

    it "allows one review per user and movie, ignoring case" do
      existing = create(:review, user_name: "Sam Pedro")
      duplicate = build(:review, movie: existing.movie, user_name: "SAM PEDRO")

      expect(duplicate).not_to be_valid
      expect(build(:review, user_name: "Sam Pedro")).to be_valid
    end

    it "is backed by a check constraint on stars" do
      review = build(:review, stars: 6)

      expect { review.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /reviews_stars_range/)
    end
  end

  describe ".newest_first" do
    it "orders by creation, newest first" do
      older = create(:review)
      newer = create(:review, movie: older.movie)

      expect(described_class.newest_first).to eq([ newer, older ])
    end
  end

  describe "rating stats" do
    let(:movie) { create(:movie) }

    it "updates the movie when a review is created, changed or removed" do
      create(:review, movie:, stars: 5)
      second = create(:review, movie:, stars: 2)
      expect(movie.reload).to have_attributes(average_stars: BigDecimal("3.5"), reviews_count: 2)

      second.update!(stars: 4)
      expect(movie.reload.average_stars).to eq(BigDecimal("4.5"))

      second.destroy!
      expect(movie.reload).to have_attributes(average_stars: BigDecimal("5"), reviews_count: 1)
    end

    it "refreshes both movies when a review moves to another movie" do
      other = create(:movie)
      review = create(:review, movie:, stars: 4)

      review.update!(movie: other)

      expect(movie.reload).to have_attributes(average_stars: nil, reviews_count: 0)
      expect(other.reload).to have_attributes(average_stars: BigDecimal("4"), reviews_count: 1)
    end
  end
end
