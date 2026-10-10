require "rails_helper"

RSpec.describe PasswordsMailer do
  describe ".reset" do
    let(:user) { create(:user) }
    let(:mail) { described_class.reset(user) }

    it "is addressed to the user" do
      expect(mail.to).to eq([ user.email_address ])
      expect(mail.subject).to eq("Reset your password")
    end

    it "links to a working reset page" do
      token = mail.text_part.decoded[%r{/passwords/([^/\s]+)/edit}, 1]

      expect(token).to be_present
      expect(User.find_by_password_reset_token!(token)).to eq(user)
    end
  end
end
