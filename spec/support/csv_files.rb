require "tmpdir"

module CsvFileHelpers
  # Writes content to a file in a per-example temporary directory and returns
  # its path. The directory is removed after the example.
  def write_csv(name, content)
    @csv_dir ||= Dir.mktmpdir
    Pathname(@csv_dir).join(name).tap { |path| path.write(content) }
  end
end

RSpec.configure do |config|
  config.include CsvFileHelpers
  config.after { FileUtils.remove_entry(@csv_dir) if @csv_dir }
end
