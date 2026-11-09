# frozen_string_literal: true

class NewsletterSubscriber < ApplicationRecord
  STATUSES = %w[pending subscribed unsubscribed].freeze
  CONFIRM_TOKEN_TTL = 48.hours
  RESEND_COOLDOWN = 10.minutes
  MAX_CONFIRMATIONS_PER_DAY = 3
  UNSUBSCRIBE_PURPOSE = :newsletter_unsubscribe

  normalizes :email, with: ->(e) { e.to_s.strip.downcase }

  validates :email, presence: true, length: { maximum: 254 },
                    format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :status, inclusion: { in: STATUSES }

  def self.find_by_confirm_token(raw)
    return unless Newsletter::Token.plausible?(raw)

    sub = find_by(confirm_token_digest: Newsletter::Token.digest(raw))
    sub if sub&.confirm_token_expires_at&.future?
  end

  # Stateless, non-expiring unsubscribe token (signed with secret_key_base), so the
  # link in every email keeps working without storing a raw token.
  def unsubscribe_token
    signed_id(purpose: UNSUBSCRIBE_PURPOSE)
  end

  def self.find_by_unsubscribe_token(raw)
    return if raw.blank? || raw.to_s.length > 512

    find_signed(raw.to_s, purpose: UNSUBSCRIBE_PURPOSE)
  end

  def subscribed? = status == "subscribed"

  # Returns the raw token (to email) or nil when the cooldown/daily cap applies.
  def mint_confirm_token!(now: Time.current)
    count = last_confirmation_sent_at && last_confirmation_sent_at > now - 24.hours ? confirmation_sent_count : 0
    return nil if last_confirmation_sent_at && last_confirmation_sent_at > now - RESEND_COOLDOWN
    return nil if count >= MAX_CONFIRMATIONS_PER_DAY

    raw, digest = Newsletter::Token.generate
    update!(confirm_token_digest: digest, confirm_token_expires_at: now + CONFIRM_TOKEN_TTL,
            confirmation_sent_count: count + 1, last_confirmation_sent_at: now)
    raw
  end

  def confirm!(now: Time.current)
    update!(status: "subscribed", confirmed_at: now, consented_at: now, unsubscribed_at: nil,
            unsubscribe_method: nil, confirm_token_digest: nil, confirm_token_expires_at: nil)
  end

  def unsubscribe!(method:, now: Time.current)
    return if status == "unsubscribed" && confirm_token_digest.nil?

    update!(status: "unsubscribed", unsubscribed_at: unsubscribed_at || now, unsubscribe_method: unsubscribe_method || method,
            confirm_token_digest: nil, confirm_token_expires_at: nil)
  end
end
