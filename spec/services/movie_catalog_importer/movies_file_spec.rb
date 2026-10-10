require "rails_helper"

RSpec.describe MovieCatalogImporter::MoviesFile do
  let(:issues) { MovieCatalogImporter::Issues.new }

  def read(content)
    described_class.new(write_csv("movies.csv", content), issues:, year_range: Movie::YEAR_RANGE).read
  end

  it "accepts a byte-order mark, header case and spacing, and non-breaking spaces" do
    catalog = read("﻿ MOVIE , description,YEAR,Director,Actor,Filming Location,Country \n" \
                   "Bom Movie,D,2000,Dir,A  B,Loc,us\n")

    expect(catalog.movies.values).to eq([ { title: "Bom Movie", description: "D", year: 2000, director: "Dir" } ])
    expect(catalog.actors).to eq("a b" => "A B")
    expect(catalog.locations.keys).to eq([ [ "loc", "US" ] ])
  end

  it "reports rows without a title or director" do
    read("Movie,Description,Year,Director,Actor,Filming location,Country\n,D,2000,Dir,,,\nX,D,2000,,,,\n")

    expect(issues.messages).to eq([ "movies.csv line 2: missing movie title", 'movies.csv line 3: missing director for "X"' ])
  end

  it "treats a header-only file as empty" do
    expect(read("Movie,Description,Year,Director,Actor,Filming location,Country\n").movies).to be_empty
  end

  it "rejects an empty file" do
    expect { read("") }.to raise_error(MovieCatalogImporter::InvalidFile, /missing column/)
  end
end
