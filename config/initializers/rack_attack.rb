# Basic abuse protection for the public JSON API.
# Counters live in Rails.cache - configure a shared store (e.g. Redis or
# solid_cache) in production so limits apply across processes.
Rack::Attack.throttle("api/ip", limit: 120, period: 1.minute) do |request|
  request.ip if request.path.start_with?("/api/")
end
