# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: 1)
    fixtures :all

    def auth_headers(user)
      token = JwtService.encode({ user_id: user.id })
      { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
    end
  end
end

class ActionDispatch::IntegrationTest
  setup do
    Rack::Attack.enabled = false
    store = Rack::Attack.cache.store
    store.clear if store.respond_to?(:clear)
  end
end
