# frozen_string_literal: true

class AppointmentMailer < ApplicationMailer
  def reschedule_instructions
    @appointment = params[:appointment]
    @reschedule_url = reschedule_url_for(@appointment.reschedule_token)
    @expires_at = @appointment.reschedule_token_expires_at
    @zone = business_zone

    mail(
      to: @appointment.email,
      subject: "Reschedule your Throne Technology appointment"
    )
  end

  helper_method :format_in_business_zone

  private

  def business_zone
    Time.find_zone(AppointmentSetting.instance.timezone) || Time.find_zone!("UTC")
  end

  # e.g. "Monday, March 16, 2026 at 10:00 AM EDT" in the booking timezone,
  # matching the times shown on the booking page.
  def format_in_business_zone(time)
    return "" if time.blank?

    time.in_time_zone(@zone || business_zone).strftime("%A, %B %-d, %Y at %-l:%M %p %Z")
  end

  def reschedule_url_for(token)
    # FRONTEND_ORIGIN may be a comma-separated list; links use the first entry.
    origin = ENV.fetch("FRONTEND_ORIGIN", "").split(",").map(&:strip).reject(&:empty?).first
    origin = (origin || "http://localhost:5173").chomp("/")
    "#{origin}/#book/reschedule/#{token}"
  end
end
