namespace :import do
  desc 'Import movies and reviews from CSV files (safe to re-run). Usage: bin/rails "import:all[movies.csv,reviews.csv]"'
  task :all, [ :movies_path, :reviews_path ] => :environment do |_task, args|
    args.with_defaults(
      movies_path: Rails.root.join("db/data/movies.csv").to_s,
      reviews_path: Rails.root.join("db/data/reviews.csv").to_s
    )

    summary = MovieCatalogImporter.call(movies_path: args[:movies_path], reviews_path: args[:reviews_path])

    puts "Imported #{summary.movies} movies, #{summary.actors} actors, " \
         "#{summary.locations} locations and #{summary.reviews} reviews."

    issues = summary.issues
    if issues.any?
      warn "#{issues.count} row(s) were skipped or had conflicting values:"
      issues.messages.each { |message| warn "  #{message}" }
      warn "  ... and #{issues.count - issues.messages.size} more" if issues.truncated?
    end
  rescue MovieCatalogImporter::InvalidFile => error
    abort "Import failed, nothing was changed. #{error.message}"
  end
end
