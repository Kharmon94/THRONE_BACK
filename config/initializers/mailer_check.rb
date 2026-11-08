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
