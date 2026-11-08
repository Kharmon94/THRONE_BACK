require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Use SECRET_KEY_BASE env var for containerized deployments (e.g. Railway).
  # Generate with: rails secret
  config.secret_key_base = ENV["SECRET_KEY_BASE"] if ENV["SECRET_KEY_BASE"].present?

  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.assume_ssl = true
  config.force_ssl = true
  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.logger($stdout)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/up"
  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [:id]
  # Use S3 when AWS_BUCKET is set; otherwise use local (ephemeral on Railway).
  if ENV["AWS_BUCKET"].present?
    config.active_storage.service = :amazon
  else
    config.active_storage.service = :local
    warn(
      "[Throne] AWS_BUCKET is not set — Active Storage is using local disk. " \
      "Uploads will not persist across Railway deploys. Set AWS_ACCESS_KEY_ID, " \
      "AWS_SECRET_ACCESS_KEY, AWS_REGION, and AWS_BUCKET for durable media."
    )
  end
  # In-process cache — enough for a single-replica portfolio API.
  config.cache_store = :memory_store
  # :async (in-process) jobs are not durable. Nothing user-facing is enqueued:
  # reschedule emails are sent synchronously (deliver_now) so failures are
  # reported to the admin instead of being lost on restart.
  config.active_job.queue_adapter = :async

  # Reverse proxies whose X-Forwarded-For entries should be trusted when
  # computing request.remote_ip (used for rate limiting). Private ranges and
  # loopback are trusted by default; add the platform edge ranges here if the
  # proxy connects from a public or CGNAT address, e.g. TRUSTED_PROXIES=100.64.0.0/10
  trusted = ENV.fetch("TRUSTED_PROXIES", "").split(",").map(&:strip).reject(&:empty?)
  if trusted.any?
    config.action_dispatch.trusted_proxies =
      ActionDispatch::RemoteIp::TRUSTED_PROXIES + trusted.map { |cidr| IPAddr.new(cidr) }
  end

  # Host authorization: let the platform health check reach /up on any Host.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
  config.action_mailer.perform_caching = false
  config.action_mailer.delivery_method = :resend
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
  Rails.application.routes.default_url_options = { host: ENV.fetch("API_HOST", "localhost"), protocol: "https" }
end
