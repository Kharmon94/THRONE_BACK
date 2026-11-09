# frozen_string_literal: true

require "digest"

module Newsletter
  # Opaque random tokens; only the SHA-256 digest is persisted.
  module Token
    module_function

    def generate
      raw = SecureRandom.urlsafe_base64(32)
      [raw, digest(raw)]
    end

    def digest(raw)
      Digest::SHA256.hexdigest(raw.to_s)
    end

    def plausible?(raw)
      raw.is_a?(String) && raw.match?(/\A[A-Za-z0-9_-]{40,64}\z/)
    end
  end
end
