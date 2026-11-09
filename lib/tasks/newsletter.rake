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
    n = Newsletter::Retention.purge_pending!
    abort "NEWSLETTER_PENDING_RETENTION_DAYS is not set to a positive integer; nothing deleted." if n.nil?

    puts "Deleted #{n} expired pending signup(s)."
  end
end
