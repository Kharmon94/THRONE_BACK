# frozen_string_literal: true

require "test_helper"

class AuthRequestTest < ActionDispatch::IntegrationTest
  test "sign_in succeeds for valid credentials" do
    post "/api/v1/auth/sign_in",
         params: { email: users(:admin).email, password: "password123" },
         as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert body["token"].present?
    assert_equal true, body["user"]["admin"]
  end

  test "sign_in fails for invalid password" do
    post "/api/v1/auth/sign_in",
         params: { email: users(:admin).email, password: "wrong" },
         as: :json

    assert_response :unauthorized
  end

  test "sign_in rejects suspended users" do
    post "/api/v1/auth/sign_in",
         params: { email: users(:suspended).email, password: "password123" },
         as: :json

    assert_response :unauthorized
    assert_match(/suspended/i, JSON.parse(response.body)["error"])
  end

  test "sign_up is forbidden when users already exist" do
    assert User.count.positive?

    post "/api/v1/auth/sign_up",
         params: { user: { email: "new@throne.test", password: "password123", password_confirmation: "password123" } },
         as: :json

    assert_response :forbidden
  end

  test "me returns current user with valid JWT" do
    get "/api/v1/auth/me", headers: auth_headers(users(:admin))

    assert_response :success
    assert_equal users(:admin).email, JSON.parse(response.body)["user"]["email"]
  end

  test "me rejects suspended user JWT" do
    get "/api/v1/auth/me", headers: auth_headers(users(:suspended))

    assert_response :unauthorized
  end
end
