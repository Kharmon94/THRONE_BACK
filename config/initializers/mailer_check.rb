# frozen_string_literal: true

# Surface missing mail configuration at boot instead of at the first send.
if Rails.env.production?
  missing = %w[RESEND_API_KEY MAILER_FROM FRONTEND_ORIGIN].reject { |key| ENV[key].present? }
  if missing.any?
    warn(
      "[Throne] Mail is not fully configured (missing: #{missing.join(', ')}). " \
      "Reschedule emails will fail or use the Resend test sender; the admin UI reports the failure."
    )
  end
end

# Newsletter flags are inert until every required launch setting is present.
# Report names only (never values) so a half-configured deploy is visible.
Rails.application.config.after_initialize do
  if Rails.env.production? && Newsletter::Config.flag?("NEWSLETTER_SIGNUP_ENABLED")
    missing = Newsletter::Config.signup_missing
    missing += Newsletter::Config.delivery_missing if Newsletter::Config.flag?("NEWSLETTER_DELIVERY_ENABLED")
    warn("[Throne] Newsletter enabled but gated off (missing: #{missing.join(', ')}).") if missing.any?
  end
end
