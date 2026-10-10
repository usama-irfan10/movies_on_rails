# Loads the bundled catalog so a fresh database (bin/rails db:setup, or the first
# `docker compose up`) is ready to use, plus a demo account in development.
# Safe to run repeatedly.
unless Rails.env.test?
  summary = MovieCatalogImporter.call(
    movies_path: Rails.root.join("db/data/movies.csv"),
    reviews_path: Rails.root.join("db/data/reviews.csv")
  )
  puts "Seeded #{summary.movies} movies and #{summary.reviews} reviews."
end

if Rails.env.development?
  User.find_or_create_by!(email_address: "demo@example.com") do |user|
    user.password = "demo-password-123"
  end
  puts "Sign in with demo@example.com / demo-password-123"
end
