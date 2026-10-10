require "rails_helper"

RSpec.describe MovieCatalogImporter::Issues do
  it "counts every issue but keeps only the first #{described_class::LIMIT} messages" do
    issues = described_class.new
    150.times { |line| issues.add("movies.csv", line, "bad row") }

    expect(issues).to have_attributes(count: 150, any?: true, truncated?: true)
    expect(issues.messages.size).to eq(described_class::LIMIT)
    expect(issues.messages.first).to eq("movies.csv line 0: bad row")
  end
end
