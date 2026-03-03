# frozen_string_literal: true

require "devise/orm/active_record"

Devise.setup do |config|
  config.secret_key = Rails.application.credentials.secret_key_base || Rails.application.secret_key_base
  config.mailer_sender = "noreply@throne.local"
  config.navigational_formats = []
  config.sign_out_via = :delete
  config.strip_whitespace_keys = [:email]
  config.skip_session_storage = [:http_auth]
  config.stretches = Rails.env.test? ? 1 : 12
  config.reconfirmable = true
  config.expire_all_remember_me_on_sign_out = true
  config.password_length = 6..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/
  config.reset_password_within = 6.hours
  config.scoped_views = false
  config.default_scope = :user
  config.router_name = nil
  config.http_authenticatable_on_xhr = false
  config.http_authenticatable = false
  config.paranoid = true
end
