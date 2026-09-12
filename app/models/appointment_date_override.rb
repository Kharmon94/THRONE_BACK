# frozen_string_literal: true

class AppointmentDateOverride < ApplicationRecord
  HHMM = /\A\d{2}:\d{2}\z/

  validates :date, presence: true, uniqueness: true
  validates :enabled, inclusion: { in: [true, false] }
  validates :start, :end, presence: true, format: { with: HHMM, message: "must be HH:MM" }
  validate :end_after_start_when_enabled

  scope :in_range, ->(from_date, to_date) {
    scope = all
    scope = scope.where("date >= ?", from_date) if from_date.present?
    scope = scope.where("date <= ?", to_date) if to_date.present?
    scope.order(:date)
  }

  def as_api_json
    {
      id: id,
      date: date.iso8601,
      enabled: enabled,
      start: start,
      end: self.end
    }
  end

  private

  def end_after_start_when_enabled
    return unless enabled?
    return unless start.to_s.match?(HHMM) && self.end.to_s.match?(HHMM)

    if minutes(self.end) <= minutes(start)
      errors.add(:end, "must be after start")
    end
  end

  def minutes(hhmm)
    hour, minute = hhmm.to_s.split(":").map(&:to_i)
    (hour * 60) + minute
  end
end
