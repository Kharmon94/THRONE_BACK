# frozen_string_literal: true

class Appointment < ApplicationRecord
  STATUSES = %w[pending confirmed declined cancelled].freeze
  BLOCKING_STATUSES = %w[pending confirmed].freeze
  RESCHEDULE_TOKEN_TTL = 72.hours

  validates :name, :email, :starts_at, :duration_minutes, :status, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :status, inclusion: { in: STATUSES }
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :reschedule_token, uniqueness: true, allow_nil: true

  scope :blocking, -> { where(status: BLOCKING_STATUSES) }
  scope :in_window, ->(from_time, to_time) {
    where(starts_at: from_time..to_time)
  }
  scope :ordered, -> { order(starts_at: :asc) }

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

  def self.find_by_valid_reschedule_token(token)
    return if token.blank?

    appointment = find_by(reschedule_token: token)
    return unless appointment&.reschedule_token_valid?

    appointment
  end
end
