class JwtService
  SECRET = ENV.fetch("JWT_SECRET", Rails.application.secret_key_base)

  def self.encode(payload, exp: 24.hours.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET)
  end

  def self.decode(token)
    body = JWT.decode(token, SECRET).first
    HashWithIndifferentAccess.new(body)
  rescue JWT::DecodeError
    nil
  end
end
