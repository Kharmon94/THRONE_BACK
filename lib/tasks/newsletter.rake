# frozen_string_literal: true

namespace :newsletter do
  desc "Show newsletter gate status (setting names only; no values, no subscriber data)"
  task readiness: :environment do
    cfg = Newsletter::Config
    puts "signup flag:   #{cfg.flag?('NEWSLETTER_SIGNUP_ENABLED')}"
    puts "delivery flag: #{cfg.flag?('NEWSLETTER_DELIVERY_ENABLED')}"
    puts "signup missing:   #{cfg.signup_missing.presence&.join(', ') || 'none'}"
    puts "delivery missing: #{cfg.delivery_missing.presence&.join(', ') || 'none'}"
    puts "signup enabled:   #{cfg.signup_enabled?}"
    puts "delivery enabled: #{cfg.delivery_enabled?}"
  end

  desc "Delete never-confirmed pending signups older than NEWSLETTER_PENDING_RETENTION_DAYS"
  task purge_pending: :environment do
    days = Newsletter::Config.pending_retention_days
    abort "NEWSLETTER_PENDING_RETENTION_DAYS is not set to a positive integer; nothing deleted." unless days

    n = NewsletterSubscriber.where(status: "pending").where("requested_at < ?", days.days.ago).delete_all
    puts "Deleted #{n} expired pending signup(s)."
  end
end
