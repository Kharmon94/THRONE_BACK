# frozen_string_literal: true

module Newsletter
  # Records a double-opt-in request. Callers always return the same response,
  # whatever happens here (enumeration-safe).
  class Subscribe
    def initialize(email:, source: nil, campaign: nil, now: Time.current)
      @email = email.to_s.strip.downcase
      @source = Attribution.source(source)
      @campaign = Attribution.campaign(campaign)
      @now = now
    end

    def call
      sub = NewsletterSubscriber.find_or_initialize_by(email: @email)
      return :already_subscribed if sub.persisted? && sub.subscribed?

      sub.assign_attributes(requested_at: @now, consent_version: Config.consent_version,
                            source: @source, campaign: @campaign)
      sub.status = "pending" if sub.new_record?
      sub.save!

      raw = sub.mint_confirm_token!(now: @now)
      unless raw
        sub.update!(last_confirmation_status: "cooldown")
        return :cooldown
      end

      deliver(sub, raw)
    rescue ActiveRecord::RecordNotUnique
      :race_ignored
    end

    private

    def deliver(sub, raw)
      unless Config.delivery_enabled?
        sub.update!(last_confirmation_status: "suppressed_by_flag")
        return :suppressed_by_flag
      end

      NewsletterMailer.with(subscriber: sub, token: raw).confirm_subscription.deliver_now
      # "accepted_by_provider" means the API accepted it, not that it was delivered.
      sub.update!(last_confirmation_status: "accepted_by_provider")
      :accepted_by_provider
    rescue StandardError => e
      Rails.logger.error("[newsletter] confirmation send failed for subscriber #{sub.id}: #{e.class}")
      sub.update!(last_confirmation_status: "failed")
      :failed
    end
  end
end
