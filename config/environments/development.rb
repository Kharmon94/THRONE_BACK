require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true

  if Rails.root.join("tmp", "caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true
    config.cache_store = :memory_store
    config.public_file_server.headers = {
      "Cache-Control" => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false
    config.cache_store = :null_store
  end

  config.active_storage.service = :local
  Rails.application.routes.default_url_options = { host: "localhost", port: 3000 }
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_caching = false
  # Use :test locally unless RESEND_API_KEY is set (then deliver via Resend).
  if ENV["RESEND_API_KEY"].present?
    config.action_mailer.delivery_method = :resend
    config.action_mailer.perform_deliveries = true
  else
    config.action_mailer.delivery_method = :test
  end
  config.active_support.deprecation = :log
  config.active_support.disallowed_deprecation = :raise
  config.active_support.disallowed_deprecation_warnings = []
end
