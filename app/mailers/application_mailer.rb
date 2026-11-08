# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  # Set MAILER_FROM to an address on a domain verified in Resend. The fallback
  # (onboarding@resend.dev) only delivers to the Resend account owner, so it is
  # for local testing only; production logs a warning at boot when it is unset.
  FALLBACK_FROM = "Throne <onboarding@resend.dev>"
  default from: -> { ENV["MAILER_FROM"].presence || FALLBACK_FROM }
  layout "mailer"
end
