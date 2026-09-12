# frozen_string_literal: true

class AppointmentMailer < ApplicationMailer
  def reschedule_instructions
    @appointment = params[:appointment]
    @reschedule_url = reschedule_url_for(@appointment.reschedule_token)
    @expires_at = @appointment.reschedule_token_expires_at

    mail(
      to: @appointment.email,
      subject: "Reschedule your Throne appointment"
    )
  end

  private

  def reschedule_url_for(token)
    origin = ENV.fetch("FRONTEND_ORIGIN", "http://localhost:5173").to_s.chomp("/")
    "#{origin}/#book/reschedule/#{token}"
  end
end
