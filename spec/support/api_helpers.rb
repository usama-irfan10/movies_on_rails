module ApiHelpers
  # Headers sent with every API request in specs: a valid bearer token.
  # Memoized, so the token is created once per example (call api_headers early
  # if an example counts queries).
  def api_headers
    @api_headers ||= { "Authorization" => "Bearer #{ApiToken.issue_for(create(:user)).plaintext}" }
  end

  def api_get(path, **options)
    get path, headers: api_headers, **options
  end

  def json
    response.parsed_body
  end

  def count_queries(&block)
    queries = 0
    callback = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)
    queries
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, type: :request
end
