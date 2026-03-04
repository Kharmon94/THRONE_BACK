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
  # Use S3 when AWS_BUCKET is set; otherwise use local (ephemeral on Railway—add AWS vars for persistent storage).
  config.active_storage.service = ENV["AWS_BUCKET"].present? ? :amazon : :local
  config.cache_store = ENV["REDIS_URL"].present? ? [:redis_cache_store, { url: ENV["REDIS_URL"] }] : :memory_store
  # Use :async (in-process) - no external queue needed. Add solid_queue gem if you need a real queue.
  config.active_job.queue_adapter = :async
  config.action_mailer.perform_caching = false
  config.action_mailer.raise_delivery_errors = false
  Rails.application.routes.default_url_options = { host: ENV.fetch("API_HOST", "localhost"), protocol: "https" }
end
