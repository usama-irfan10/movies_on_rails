require "csv"

class MovieCatalogImporter
  # Streams a CSV file as { "header" => "value" } hashes, after checking that
  # the required columns exist. Headers are matched ignoring case and
  # surrounding spaces; values have surrounding whitespace removed and inner
  # runs of whitespace (including non-breaking spaces) collapsed to one space.
  #
  # Raises InvalidFile when the file is missing, malformed or lacks a column.
  class CsvFile
    OPTIONS = {
      headers: true,
      encoding: "bom|utf-8",
      header_converters: ->(header) { header.to_s.strip.downcase }
    }.freeze

    attr_reader :name

    def initialize(path, columns:)
      @path = path.to_s
      @columns = columns
      @name = File.basename(@path)
    end

    # Yields each row with its line number (the header is line 1).
    def each_row
      return enum_for(:each_row) unless block_given?

      CSV.open(@path, **OPTIONS) do |csv|
        headers_checked = false

        csv.each do |row|
          headers_checked ||= check_headers!(row.headers)
          yield normalize(row), csv.lineno
        end

        check_headers!(csv.headers) unless headers_checked # empty or header-only file
      end
    rescue Errno::ENOENT, Errno::EISDIR
      raise InvalidFile, "#{name}: file not found"
    rescue CSV::MalformedCSVError => error # also covers invalid UTF-8
      raise InvalidFile, "#{name}: #{error.message}"
    end

    private
      def check_headers!(headers)
        missing = @columns - Array(headers)
        raise InvalidFile, "#{name}: missing column(s) #{missing.join(', ')}" if missing.any?

        true
      end

      def normalize(row)
        row.to_h.transform_values { |value| value.to_s.gsub(/[[:space:]]+/, " ").strip }
      end
  end
end
