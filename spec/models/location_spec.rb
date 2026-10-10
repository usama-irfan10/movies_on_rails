require "rails_helper"

RSpec.describe Location do
  describe "validations" do
    subject { build(:location) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:country) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:country).case_insensitive }
  end

  it "normalizes the country code" do
    expect(build(:location, country: " us ").country).to eq("US")
  end

  it "allows the same place name in different countries" do
    create(:location, name: "Paris", country: "FR")

    expect(build(:location, name: "Paris", country: "US")).to be_valid
  end
end
