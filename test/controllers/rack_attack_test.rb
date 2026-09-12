# frozen_string_literal: true

require "test_helper"

class RackAttackRequestTest < ActionDispatch::IntegrationTest
  setup do
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.reset!
    Rack::Attack.enabled = true
  end

  teardown do
    Rack::Attack.enabled = false
    Rack::Attack.reset!
  end

  test "sign_in is throttled after limit" do
    limit = 5
    (limit + 1).times do |i|
      post "/api/v1/auth/sign_in",
           params: { email: "nobody@throne.test", password: "x" },
           as: :json
      if i < limit
        assert_response :unauthorized
      else
        assert_response :too_many_requests
        assert_equal "Too many requests. Please try again later.", JSON.parse(response.body)["error"]
      end
    end
  end
end
