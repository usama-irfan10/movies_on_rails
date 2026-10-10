# Loads the bundled catalog so a fresh database (bin/rails db:setup, or the first
# `docker compose up`) is ready to use. Safe to run repeatedly.
unless Rails.env.test?
  summary = MovieCatalogImporter.call(
    movies_path: Rails.root.join("db/data/movies.csv"),
    reviews_path: Rails.root.join("db/data/reviews.csv")
  )
  puts "Seeded #{summary.movies} movies and #{summary.reviews} reviews."
end
