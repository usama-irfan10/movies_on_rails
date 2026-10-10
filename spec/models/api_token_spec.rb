require "rails_helper"

RSpec.describe ApiToken do
  let(:user) { create(:user) }

  it { is_expected.to belong_to(:user) }

  describe ".issue_for" do
    it "returns a token whose plaintext is not stored" do
      token = described_class.issue_for(user)

      expect(token.plaintext).to be_present
      expect(token.token_digest).to eq(described_class.digest(token.plaintext))
      expect(described_class.find(token.id).plaintext).to be_nil # only the issuing instance knows it
      expect(described_class.where(token_digest: token.plaintext)).to be_empty
    end

    it "issues distinct tokens that expire after the default lifetime" do
      first = described_class.issue_for(user)
      second = described_class.issue_for(user)

      expect(first.plaintext).not_to eq(second.plaintext)
      expect(first.expires_at).to be_within(1.minute).of(described_class::DEFAULT_TTL.from_now)
    end
  end

  describe ".find_active_by_plaintext" do
    let!(:token) { described_class.issue_for(user) }

    it "finds a live token" do
      expect(described_class.find_active_by_plaintext(token.plaintext)).to eq(token)
    end

    it "ignores blank, unknown and expired tokens" do
      expect(described_class.find_active_by_plaintext(nil)).to be_nil
      expect(described_class.find_active_by_plaintext("")).to be_nil
      expect(described_class.find_active_by_plaintext("unknown")).to be_nil

      token.update!(expires_at: 1.minute.ago)
      expect(described_class.find_active_by_plaintext(token.plaintext)).to be_nil
    end
  end

  describe "#record_usage!" do
    it "stamps last_used_at, but not more than once per interval" do
      token = described_class.issue_for(user)

      token.record_usage!
      first_use = token.reload.last_used_at
      token.record_usage!

      expect(first_use).to be_present
      expect(token.reload.last_used_at).to eq(first_use)
    end
  end

  it "is revoked when the user's password changes" do
    described_class.issue_for(user)

    user.update!(password: "a-brand-new-password")

    expect(user.api_tokens).to be_empty
  end
end
