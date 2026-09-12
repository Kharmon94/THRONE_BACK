# frozen_string_literal: true

Rails.application.config.hosts << "localhost" << "127.0.0.1"

# ActionDispatch integration tests use this default host.
if Rails.env.test?
  Rails.application.config.hosts << "www.example.com" << "example.com"
end

api_host = ENV["API_HOST"].to_s.strip
if api_host.present?
  host = api_host.sub(%r{\Ahttps?://}i, "").split("/").first
  Rails.application.config.hosts << host if host.present?
end

ENV.fetch("RAILS_HOSTS", "").split(",").each do |entry|
  host = entry.strip.sub(%r{\Ahttps?://}i, "").split("/").first
  next if host.blank?

  Rails.application.config.hosts << host
end
