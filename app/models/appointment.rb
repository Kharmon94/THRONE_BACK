# frozen_string_literal: true

class Appointment < ApplicationRecord
  STATUSES = %w[pending confirmed declined cancelled].freeze
  BLOCKING_STATUSES = %w[pending confirmed].freeze
  RESCHEDULE_TOKEN_TTL = 72.hours
  NAME_MAX = 120
  EMAIL_MAX = 254
  COMPANY_MAX = 160
  NOTES_MAX = 4000

  before_validation :strip_text_fields
  before_save :clear_reschedule_token_when_inactive

  validates :name, :email, :starts_at, :duration_minutes, :status, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  # Length limits apply when a field is written, so existing rows with longer
  # legacy values can still have their status changed by an admin.
  validates :name, length: { maximum: NAME_MAX }, if: :will_save_change_to_name?
  validates :email, length: { maximum: EMAIL_MAX }, if: :will_save_change_to_email?
  validates :company, length: { maximum: COMPANY_MAX }, allow_blank: true, if: :will_save_change_to_company?
  validates :notes, length: { maximum: NOTES_MAX }, allow_blank: true, if: :will_save_change_to_notes?
  validates :status, inclusion: { in: STATUSES }
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :reschedule_token, uniqueness: true, allow_nil: true

  scope :blocking, -> { where(status: BLOCKING_STATUSES) }
  scope :in_window, ->(from_time, to_time) {
    where(starts_at: from_time..to_time)
  }
  scope :ordered, -> { order(starts_at: :asc) }

  def blocking?
    BLOCKING_STATUSES.include?(status)
  end

  def ends_at
    starts_at + duration_minutes.minutes
  end

  def overlaps?(other_start, other_end)
    starts_at < other_end && ends_at > other_start
  end

  def mint_reschedule_token!(ttl: RESCHEDULE_TOKEN_TTL)
    update!(
      reschedule_token: SecureRandom.urlsafe_base64(32),
      reschedule_token_expires_at: Time.current + ttl
    )
  end

  def clear_reschedule_token!
    update!(reschedule_token: nil, reschedule_token_expires_at: nil)
  end

  def reschedule_token_valid?
    reschedule_token.present? &&
      reschedule_token_expires_at.present? &&
      reschedule_token_expires_at > Time.current
  end

  # A reschedule link only works while the booking is still active
  # (pending/confirmed). Declined or cancelled bookings cannot be revived.
  def self.find_by_valid_reschedule_token(token)
    return if token.blank?

    appointment = find_by(reschedule_token: token.to_s)
    return unless appointment&.reschedule_token_valid?
    return unless appointment.blocking?

    appointment
  end

  private

  # Declining or cancelling a booking invalidates any outstanding reschedule link.
  def clear_reschedule_token_when_inactive
    return unless will_save_change_to_status?
    return if blocking?

    self.reschedule_token = nil
    self.reschedule_token_expires_at = nil
  end

  def strip_text_fields
    self.name = name.strip if name.is_a?(String)
    self.email = email.strip if email.is_a?(String)
    self.company = company.strip.presence if company.is_a?(String)
    self.notes = notes.strip.presence if notes.is_a?(String)
  end
end
