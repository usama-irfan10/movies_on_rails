require "rails_helper"

RSpec.describe User do
  it { is_expected.to have_secure_password }
  it { is_expected.to have_many(:sessions).dependent(:delete_all) }

  describe "validations" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:email_address) }

    it "requires a well-formed email address" do
      expect(build(:user, email_address: "not-an-email")).not_to be_valid
    end

    it "requires a unique email address, ignoring case and whitespace" do
      create(:user, email_address: "person@example.com")

      expect(build(:user, email_address: "  PERSON@Example.com ")).not_to be_valid
    end

    it "requires a password of at least #{User::MIN_PASSWORD_LENGTH} characters" do
      expect(build(:user, password: "a" * (User::MIN_PASSWORD_LENGTH - 1))).not_to be_valid
      expect(build(:user, password: "a" * User::MIN_PASSWORD_LENGTH)).to be_valid
    end
  end

  it "normalizes the email address" do
    expect(build(:user, email_address: "  Person@Example.COM ").email_address).to eq("person@example.com")
  end

  describe ".authenticate_by" do
    let!(:user) { create(:user) }

    it "finds the user by email (any case) and password" do
      found = described_class.authenticate_by(email_address: user.email_address.upcase, password: user.password)

      expect(found).to eq(user)
    end

    it "rejects a wrong password, an unknown email and a blank password" do
      expect(described_class.authenticate_by(email_address: user.email_address, password: "wrong")).to be_nil
      expect(described_class.authenticate_by(email_address: "nobody@example.com", password: "x")).to be_nil
      expect(described_class.authenticate_by(email_address: user.email_address, password: "")).to be_nil
    end
  end

  it "signs the user out everywhere when the password changes" do
    user = create(:user)
    user.sessions.create!

    user.update!(password: "a-brand-new-password")

    expect(user.sessions).to be_empty
  end
end
