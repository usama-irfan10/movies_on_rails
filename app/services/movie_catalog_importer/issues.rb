class MovieCatalogImporter
  # Problems found while importing (skipped rows, conflicting values). Every
  # issue is counted, but only the first LIMIT messages are kept so that a badly
  # broken file cannot use unbounded memory.
  class Issues
    LIMIT = 100

    attr_reader :count, :messages

    def initialize
      @count = 0
      @messages = []
    end

    def add(file, line, message)
      @count += 1
      @messages << "#{file} line #{line}: #{message}" if @messages.size < LIMIT
    end

    def any?
      count.positive?
    end

    def truncated?
      count > messages.size
    end
  end
end
