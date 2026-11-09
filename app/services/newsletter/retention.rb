# frozen_string_literal: true

module Newsletter
  # Deletes never-confirmed signups older than NEWSLETTER_PENDING_RETENTION_DAYS.
  # Runs automatically (at most hourly per process) on newsletter API activity,
  # and via `bin/rails newsletter:purge_pending` for a scheduled daily run.
  # Does nothing when the retention setting is missing: nothing is invented.
  module Retention
    INTERVAL = 1.hour
    @last_run_at = nil
    @mutex = Mutex.new

    module_function

    def purge_pending!(now: Time.current)
      days = Config.pending_retention_days
      return nil unless days

      NewsletterSubscriber.where(status: "pending").where("requested_at < ?", now - days.days).delete_all
    end

    def maybe_purge!(now: Time.current)
      due = @mutex.synchronize do
        next false if @last_run_at && @last_run_at > now - INTERVAL

        @last_run_at = now
        true
      end
      purge_pending!(now: now) if due
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.warn("[newsletter] pending purge skipped: #{e.class}")
      nil
    end

    def reset!
      @mutex.synchronize { @last_run_at = nil }
    end
  end
end
