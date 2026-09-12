# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAILER_FROM", "Throne <onboarding@resend.dev>") }
  layout "mailer"
end
