class JwtService
  SECRET = ENV.fetch("JWT_SECRET", Rails.application.secret_key_base)
  ALGORITHM = "HS256".freeze
  DEFAULT_TTL_HOURS = 12

  # Session length in hours (JWT_TTL_HOURS, clamped to 1..72, default 12).
  def self.ttl
    hours = ENV["JWT_TTL_HOURS"].to_s.strip
    hours = hours.match?(/\A\d+\z/) ? hours.to_i : DEFAULT_TTL_HOURS
    hours.clamp(1, 72).hours
  end

  # Optional global revocation: set JWT_REVOKED_BEFORE to an ISO8601 time and
  # every token issued before it (or without an issued-at claim) is rejected.
  # Lets an operator force all admins to sign in again without a migration.
  def self.revoked_before
    raw = ENV["JWT_REVOKED_BEFORE"].to_s.strip
    return nil if raw.empty?

    Time.iso8601(raw)
  rescue ArgumentError
    nil
  end

  def self.encode(payload, exp: nil)
    now = Time.current
    payload = payload.dup
    payload[:iat] = now.to_i
    payload[:exp] = (exp || (now + ttl)).to_i
    JWT.encode(payload, SECRET, ALGORITHM)
  end

  def self.decode(token)
    body = JWT.decode(token.to_s, SECRET, true, { algorithm: ALGORITHM }).first
    claims = HashWithIndifferentAccess.new(body)
    cutoff = revoked_before
    return nil if cutoff && (claims[:iat].blank? || claims[:iat].to_i < cutoff.to_i)

    claims
  rescue JWT::DecodeError
    nil
  end
end
