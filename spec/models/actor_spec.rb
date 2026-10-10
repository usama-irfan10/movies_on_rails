require "rails_helper"

RSpec.describe Actor do
  describe "validations" do
    subject { build(:actor) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
  end

  describe ".matching" do
    before { create(:actor, name: "Nicolas Cage") }

    it "matches case-insensitive substrings" do
      expect(described_class.matching("  COLAS ").pluck(:name)).to eq([ "Nicolas Cage" ])
    end

    it "treats LIKE wildcards literally" do
      expect(described_class.matching("%")).to be_empty
      expect(described_class.matching("N_colas")).to be_empty
      expect(described_class.matching("\\")).to be_empty
    end
  end
end
