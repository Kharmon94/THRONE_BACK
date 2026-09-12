# frozen_string_literal: true

class AppointmentSetting < ApplicationRecord
  WEEKDAYS = %w[mon tue wed thu fri sat sun].freeze
  DEFAULTS_PATH = Rails.root.join("config/appointments.yml")

  validates :timezone, :slot_duration_minutes, :lead_time_hours, :bookable_days_ahead, :weekly_hours, presence: true
  validates :slot_duration_minutes, :bookable_days_ahead,
            numericality: { only_integer: true, greater_than: 0 }
  validates :lead_time_hours, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :weekly_hours_shape
  validate :timezone_must_be_valid

  def self.instance
    first || seed_from_yaml!
  end

  def self.seed_from_yaml!
    config = defaults_from_yaml
    create!(
      timezone: config.fetch("timezone"),
      slot_duration_minutes: config.fetch("slot_duration_minutes"),
      lead_time_hours: config.fetch("lead_time_hours"),
      bookable_days_ahead: config.fetch("bookable_days_ahead"),
      weekly_hours: config.fetch("weekly_hours")
    )
  end

  def self.defaults_from_yaml
    YAML.safe_load_file(DEFAULTS_PATH)
  end

  def as_api_json
    {
      timezone: timezone,
      slot_duration_minutes: slot_duration_minutes,
      lead_time_hours: lead_time_hours,
      bookable_days_ahead: bookable_days_ahead,
      weekly_hours: weekly_hours
    }
  end

  private

  def weekly_hours_shape
    unless weekly_hours.is_a?(Hash)
      errors.add(:weekly_hours, "must be an object")
      return
    end

    WEEKDAYS.each do |day|
      day_hours = weekly_hours[day] || weekly_hours[day.to_sym]
      unless day_hours.is_a?(Hash)
        errors.add(:weekly_hours, "must include #{day}")
        next
      end

      enabled = day_hours["enabled"].nil? ? day_hours[:enabled] : day_hours["enabled"]
      start_time = day_hours["start"] || day_hours[:start]
      end_time = day_hours["end"] || day_hours[:end]

      unless [true, false].include?(enabled)
        errors.add(:weekly_hours, "#{day}.enabled must be boolean")
      end
      unless start_time.to_s.match?(/\A\d{2}:\d{2}\z/) && end_time.to_s.match?(/\A\d{2}:\d{2}\z/)
        errors.add(:weekly_hours, "#{day} start/end must be HH:MM")
      end
    end
  end

  def timezone_must_be_valid
    Time.find_zone!(timezone)
  rescue ArgumentError, TZInfo::InvalidTimezoneIdentifier
    errors.add(:timezone, "is not a valid IANA timezone")
  end
end
