class MovieCatalogImporter
  # Reads movies.csv, which has one row per movie x actor x filming location,
  # and collapses it into unique movies, actors and locations plus the links
  # between them.
  #
  # Records are keyed case-insensitively; the first spelling seen is kept.
  # A row with an unusable title, director or year is skipped. When rows for
  # the same movie disagree on its details, the first row wins and the others
  # are reported.
  class MoviesFile
    COLUMNS = {
      title: "movie", description: "description", year: "year", director: "director",
      actor: "actor", location: "filming location", country: "country"
    }.freeze

    # movies:          { title_key => { title:, description:, year:, director: } }
    # actors:          { name_key => name }
    # locations:       { [name_key, country] => { name:, country: } }
    # movie_actors:    Set of [title_key, name_key]
    # movie_locations: Set of [title_key, [name_key, country]]
    Catalog = Struct.new(:movies, :actors, :locations, :movie_actors, :movie_locations, keyword_init: true)

    def initialize(path, issues:, year_range:)
      @file = CsvFile.new(path, columns: COLUMNS.values)
      @issues = issues
      @year_range = year_range
    end

    def read
      catalog = Catalog.new(movies: {}, actors: {}, locations: {}, movie_actors: Set.new, movie_locations: Set.new)
      first_lines = {}

      @file.each_row do |row, line|
        values = COLUMNS.transform_values { |header| row[header] }
        movie = movie_from(values, line) or next
        key = movie[:title].downcase

        if (kept = catalog.movies[key])
          report(line, "conflicting details for #{movie[:title].inspect} (kept the values from line #{first_lines[key]})") if kept.except(:title) != movie.except(:title)
        else
          catalog.movies[key] = movie
          first_lines[key] = line
        end

        add_actor(catalog, key, values[:actor])
        add_location(catalog, key, values, line)
      end

      catalog
    end

    private
      def movie_from(values, line)
        title, director = values.values_at(:title, :director)
        year = Integer(values[:year], 10, exception: false)

        if title.empty?
          report(line, "missing movie title")
        elsif director.empty?
          report(line, "missing director for #{title.inspect}")
        elsif !@year_range.cover?(year)
          report(line, "invalid year #{values[:year].inspect} for #{title.inspect}")
        else
          { title:, description: values[:description].then { |text| text.empty? ? nil : text }, year:, director: }
        end
      end

      def add_actor(catalog, movie_key, name)
        return if name.empty?

        key = name.downcase
        catalog.actors[key] ||= name
        catalog.movie_actors << [ movie_key, key ]
      end

      def add_location(catalog, movie_key, values, line)
        name, country = values[:location], values[:country].upcase
        return if name.empty? && country.empty?

        if name.empty? || country.empty?
          report(line, name.empty? ? "country #{country.inspect} has no filming location" : "filming location #{name.inspect} has no country")
          return
        end

        key = [ name.downcase, country ]
        catalog.locations[key] ||= { name:, country: }
        catalog.movie_locations << [ movie_key, key ]
      end

      def report(line, message)
        @issues.add(@file.name, line, message)
        nil
      end
  end
end
