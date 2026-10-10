require "rails_helper"

RSpec.describe MailInbox do
  def with_env(values)
    original = ENV.to_h.slice(*values.keys)
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    values.each_key { |key| ENV[key] = original[key] }
  end

  def in_environment(name, &block)
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new(name))
    block.call
  end

  describe ".enabled?" do
    it "is always on in development" do
      in_environment("development") { expect(described_class).to be_enabled }
    end

    it "is off in production without credentials" do
      with_env("MAIL_INBOX_USERNAME" => nil, "MAIL_INBOX_PASSWORD" => nil) do
        in_environment("production") { expect(described_class).not_to be_enabled }
      end
    end

    it "stays off in production when only one credential is set" do
      with_env("MAIL_INBOX_USERNAME" => "dev", "MAIL_INBOX_PASSWORD" => "") do
        in_environment("production") { expect(described_class).not_to be_enabled }
      end
    end

    it "is on in production when both credentials are set" do
      with_env("MAIL_INBOX_USERNAME" => "dev", "MAIL_INBOX_PASSWORD" => "secret") do
        in_environment("production") { expect(described_class).to be_enabled }
      end
    end

    it "is off in test" do
      expect(described_class).not_to be_enabled
    end
  end

  describe ".credentials" do
    it "returns the basic auth name and password" do
      with_env("MAIL_INBOX_USERNAME" => "dev", "MAIL_INBOX_PASSWORD" => "secret") do
        expect(described_class.credentials).to eq(name: "dev", password: "secret")
      end
    end
  end
end
