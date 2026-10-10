class MovieCatalogImporter
  # Streams reviews.csv in batches of valid rows. Rows without a movie title
  # or user, or with stars outside the allowed range, are reported and skipped.
  # Matching reviews to movies happens in MovieCatalogImporter.
  class ReviewsFile
    COLUMNS = { title: "movie", user_name: "user", stars: "stars", comment: "review" }.freeze

    def initialize(path, issues:, stars_range:)
      @file = CsvFile.new(path, columns: COLUMNS.values)
      @issues = issues
      @stars_range = stars_range
    end

    def name
      @file.name
    end

    # Yields arrays of { title:, user_name:, stars:, comment:, line: }.
    def each_batch(size)
      return enum_for(:each_batch, size) unless block_given?

      batch = []
      @file.each_row do |row, line|
        review = review_from(row, line) or next
        batch << review
        next if batch.size < size

        yield batch
        batch = []
      end
      yield batch if batch.any?
    end

    private
      def review_from(row, line)
        values = COLUMNS.transform_values { |header| row[header] }
        stars = Integer(values[:stars], 10, exception: false)

        if values[:title].empty?
          report(line, "missing movie title")
        elsif values[:user_name].empty?
          report(line, "missing user")
        elsif !@stars_range.cover?(stars)
          report(line, "stars must be a whole number from #{@stars_range.min} to #{@stars_range.max}, got #{values[:stars].inspect}")
        else
          { title: values[:title], user_name: values[:user_name], stars:, comment: values[:comment].then { |text| text.empty? ? nil : text }, line: }
        end
      end

      def report(line, message)
        @issues.add(@file.name, line, message)
        nil
      end
  end
end
