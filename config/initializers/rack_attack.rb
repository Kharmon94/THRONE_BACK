# frozen_string_literal: true

class Rack::Attack
  # Per-process memory store is fine for a single-replica portfolio.
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  safelist("allow health checks") do |req|
    req.path == "/up"
  end

  throttle("auth/sign_in", limit: 5, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/auth/sign_in" && req.post?
  end

  throttle("auth/sign_up", limit: 3, period: 1.hour) do |req|
    req.ip if req.path == "/api/v1/auth/sign_up" && req.post?
  end

  throttle("appointments/create", limit: 5, period: 1.hour) do |req|
    req.ip if req.path == "/api/v1/appointments" && req.post?
  end

  self.throttled_responder = lambda do |_request|
    [
      429,
      { "Content-Type" => "application/json" },
      [{ error: "Too many requests. Please try again later." }.to_json]
    ]
  end
end
