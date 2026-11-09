# frozen_string_literal: true

module Newsletter
  # Feature gates. Everything is OFF unless explicitly enabled AND the launch
  # configuration Kyle must decide is present. No defaults are invented for
  # sender, privacy or retention values.
  module Config
    SIGNUP_REQUIRED = %w[
      NEWSLETTER_PRIVACY_URL
      NEWSLETTER_CONSENT_VERSION
      NEWSLETTER_PENDING_RETENTION_DAYS
      FRONTEND_ORIGIN
    ].freeze
    DELIVERY_REQUIRED = %w[MAILER_FROM NEWSLETTER_REPLY_TO].freeze

    module_function

    def flag?(name)
      ENV[name].to_s.strip.casecmp?("true")
    end

    # Names (never values) of required settings that are missing or invalid.
    def signup_missing
      missing = SIGNUP_REQUIRED.reject { |k| ENV[k].to_s.strip.present? }
      missing << "NEWSLETTER_PRIVACY_URL(https)" if ENV["NEWSLETTER_PRIVACY_URL"].present? && !https_url?(ENV["NEWSLETTER_PRIVACY_URL"])
      missing << "NEWSLETTER_PENDING_RETENTION_DAYS(positive integer)" if ENV["NEWSLETTER_PENDING_RETENTION_DAYS"].present? && pending_retention_days.nil?
      missing << "API_HOST" if Rails.env.production? && ENV["API_HOST"].to_s.strip.empty?
      missing
    end

    def delivery_missing
      missing = DELIVERY_REQUIRED.reject { |k| ENV[k].to_s.strip.present? }
      # The Resend sandbox sender only reaches the account owner; never a real subscriber.
      missing << "MAILER_FROM(verified domain, not resend.dev)" if ENV["MAILER_FROM"].to_s.downcase.include?("resend.dev")
      if ActionMailer::Base.delivery_method == :resend && ENV["RESEND_API_KEY"].to_s.strip.empty?
        missing << "RESEND_API_KEY"
      end
      missing
    end

    def signup_enabled?
      flag?("NEWSLETTER_SIGNUP_ENABLED") && signup_missing.empty?
    end

    def delivery_enabled?
      signup_enabled? && flag?("NEWSLETTER_DELIVERY_ENABLED") && delivery_missing.empty?
    end

    def privacy_url = ENV["NEWSLETTER_PRIVACY_URL"].to_s.strip
    def consent_version = ENV["NEWSLETTER_CONSENT_VERSION"].to_s.strip
    def reply_to = ENV["NEWSLETTER_REPLY_TO"].to_s.strip

    def pending_retention_days
      v = ENV["NEWSLETTER_PENDING_RETENTION_DAYS"].to_s.strip
      v.match?(/\A[1-9]\d{0,3}\z/) ? v.to_i : nil
    end

    def frontend_origin
      origin = ENV.fetch("FRONTEND_ORIGIN", "").split(",").map(&:strip).reject(&:empty?).first
      (origin || "http://localhost:5173").chomp("/")
    end

    def https_url?(value)
      uri = URI.parse(value.to_s.strip)
      uri.is_a?(URI::HTTPS) && uri.host.present?
    rescue URI::InvalidURIError
      false
    end
  end
end
