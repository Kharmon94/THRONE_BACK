# frozen_string_literal: true

class Rack::Attack
  # Counters live in a per-process MemoryStore. That is correct for the current
  # single-process Puma setup (WEB_CONCURRENCY unset/0). With multiple Puma
  # workers or replicas each process keeps its own counters, so effective limits
  # multiply; move to a shared store (e.g. Redis) before scaling out.
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  if Rails.env.production? && ENV.fetch("WEB_CONCURRENCY", "0").to_i > 1
    warn("[Throne] WEB_CONCURRENCY>1: Rack::Attack limits are per worker (MemoryStore).")
  end

  # Client IP as computed by ActionDispatch::RemoteIp, which honours
  # config.action_dispatch.trusted_proxies (see TRUSTED_PROXIES in production.rb).
  # Falls back to Rack's own X-Forwarded-For handling.
  def self.client_ip(req)
    (req.env["action_dispatch.remote_ip"] || req.ip).to_s
  end

  safelist("allow health checks") do |req|
    req.path == "/up"
  end

  throttle("auth/sign_in", limit: 5, period: 1.minute) do |req|
    client_ip(req) if req.path == "/api/v1/auth/sign_in" && req.post?
  end

  # Also limit by submitted email so rotating IPs cannot hammer one account.
  throttle("auth/sign_in/email", limit: 10, period: 15.minutes) do |req|
    if req.path == "/api/v1/auth/sign_in" && req.post?
      email = req.params["email"] || req.params.dig("user", "email") rescue nil
      email.to_s.strip.downcase.presence
    end
  end

  throttle("auth/sign_up", limit: 3, period: 1.hour) do |req|
    client_ip(req) if req.path == "/api/v1/auth/sign_up" && req.post?
  end

  throttle("appointments/create", limit: 5, period: 1.hour) do |req|
    client_ip(req) if req.path == "/api/v1/appointments" && req.post?
  end

  throttle("appointments/reschedule", limit: 10, period: 1.hour) do |req|
    client_ip(req) if req.path.start_with?("/api/v1/appointments/reschedule/") && (req.patch? || req.put?)
  end

  throttle("appointments/reschedule/lookup", limit: 30, period: 10.minutes) do |req|
    client_ip(req) if req.path.start_with?("/api/v1/appointments/reschedule/") && req.get?
  end

  throttle("appointments/slots", limit: 120, period: 5.minutes) do |req|
    client_ip(req) if req.path == "/api/v1/appointments/slots" && req.get?
  end

  self.throttled_responder = lambda do |_request|
    [
      429,
      { "Content-Type" => "application/json", "Retry-After" => "60" },
      [{ error: "Too many requests. Please try again later." }.to_json]
    ]
  end
end
