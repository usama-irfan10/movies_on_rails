# Abuse protection. Counters live in Rails.cache - configure a shared store
# (e.g. Redis or solid_cache) in production so limits apply across processes.
Rack::Attack.throttle("api/ip", limit: 120, period: 1.minute) do |request|
  request.ip if request.path.start_with?("/api/")
end

# Credential endpoints get much tighter limits to slow down password guessing.
Rack::Attack.throttle("api/tokens/ip", limit: 10, period: 1.minute) do |request|
  request.ip if request.post? && request.path == "/api/v1/tokens"
end

Rack::Attack.throttle("passwords/ip", limit: 5, period: 15.minutes) do |request|
  request.ip if request.post? && request.path == "/passwords"
end

# The production mail inbox is behind basic auth; slow down password guessing there too.
Rack::Attack.throttle("letter_opener/ip", limit: 30, period: 1.minute) do |request|
  request.ip if request.path.start_with?("/letter_opener")
end

Rack::Attack.throttled_responder = lambda do |request|
  retry_after = request.env.fetch("rack.attack.match_data", {})[:period].to_s
  headers = { "Retry-After" => retry_after }

  if request.path.start_with?("/api/")
    [ 429, headers.merge("Content-Type" => "application/json"), [ { error: "Too many requests" }.to_json ] ]
  else
    [ 429, headers.merge("Content-Type" => "text/plain"), [ "Too many requests. Try again later.\n" ] ]
  end
end
