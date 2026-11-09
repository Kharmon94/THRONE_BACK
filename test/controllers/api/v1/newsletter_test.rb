# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

# Newsletter phase 1. Mail uses the :test delivery method (no network); all
# values below are test-only placeholders, not launch decisions.
class NewsletterRequestTest < ActionDispatch::IntegrationTest
  NL_ENV = %w[NEWSLETTER_SIGNUP_ENABLED NEWSLETTER_DELIVERY_ENABLED NEWSLETTER_PRIVACY_URL
              NEWSLETTER_CONSENT_VERSION NEWSLETTER_PENDING_RETENTION_DAYS FRONTEND_ORIGIN
              MAILER_FROM NEWSLETTER_REPLY_TO].freeze
  SIGNUP_ENV = {
    "NEWSLETTER_SIGNUP_ENABLED" => "true",
    "NEWSLETTER_PRIVACY_URL" => "https://site.test/privacy",
    "NEWSLETTER_CONSENT_VERSION" => "test-v1",
    "NEWSLETTER_PENDING_RETENTION_DAYS" => "30",
    "FRONTEND_ORIGIN" => "https://site.test"
  }.freeze
  DELIVERY_ENV = { "NEWSLETTER_DELIVERY_ENABLED" => "true", "MAILER_FROM" => "Throne Test <news@mail.site.test>",
                   "NEWSLETTER_REPLY_TO" => "reply@site.test" }.freeze

  setup do
    @saved = NL_ENV.to_h { |k| [k, ENV[k]] }
    NL_ENV.each { |k| ENV.delete(k) }
    NewsletterSubscriber.delete_all
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    @saved.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    travel_back
  end

  def enable_signup! = SIGNUP_ENV.each { |k, v| ENV[k] = v }
  def enable_delivery! = enable_signup!.then { DELIVERY_ENV.each { |k, v| ENV[k] = v } }

  def subscribe(email = "reader@example.com", **extra)
    post "/api/v1/newsletter/subscriptions", params: { email: email, consent: true, **extra }, as: :json
  end

  def token_from_last_mail
    body = ActionMailer::Base.deliveries.last.text_part.body.to_s
    body[%r{/newsletter#confirm=([A-Za-z0-9_-]+)}, 1]
  end

  # --- hard gates ---------------------------------------------------------------
  test "disabled by default: config closed, signup and confirm 404, nothing stored or sent" do
    get "/api/v1/newsletter/config"
    assert_equal({ "signup_open" => false }, response.parsed_body)
    subscribe
    assert_response :not_found
    post "/api/v1/newsletter/confirmations", params: { token: "x" * 43 }, as: :json
    assert_response :not_found
    assert_equal 0, NewsletterSubscriber.count
    assert_empty ActionMailer::Base.deliveries
  end

  test "signup flag alone does not open signup without required launch settings" do
    ENV["NEWSLETTER_SIGNUP_ENABLED"] = "true"
    subscribe
    assert_response :not_found
    ENV["NEWSLETTER_PRIVACY_URL"] = "http://insecure.test/privacy" # must be https
    SIGNUP_ENV.except("NEWSLETTER_PRIVACY_URL").each { |k, v| ENV[k] = v }
    subscribe
    assert_response :not_found
    assert_includes Newsletter::Config.signup_missing, "NEWSLETTER_PRIVACY_URL(https)"
  end

  test "signup on, delivery off: stores pending with digest only and sends nothing" do
    enable_signup!
    get "/api/v1/newsletter/config"
    assert_equal true, response.parsed_body["signup_open"]
    assert_equal "https://site.test/privacy", response.parsed_body["privacy_url"]
    subscribe
    assert_response :accepted
    assert_equal({ "status" => "check_email" }, response.parsed_body)
    sub = NewsletterSubscriber.sole
    assert_equal "pending", sub.status
    assert_equal "suppressed_by_flag", sub.last_confirmation_status
    assert_equal "test-v1", sub.consent_version
    assert_match(/\A\h{64}\z/, sub.confirm_token_digest)
    assert_empty ActionMailer::Base.deliveries
  end

  test "delivery is gated off for the resend.dev sandbox sender or a missing reply-to" do
    enable_delivery!
    ENV["MAILER_FROM"] = "Throne <onboarding@resend.dev>"
    refute Newsletter::Config.delivery_enabled?
    ENV["MAILER_FROM"] = DELIVERY_ENV["MAILER_FROM"]
    ENV.delete("NEWSLETTER_REPLY_TO")
    refute Newsletter::Config.delivery_enabled?
    subscribe
    assert_empty ActionMailer::Base.deliveries
  end

  # --- double opt-in ------------------------------------------------------------
  test "delivery on: one confirmation email; raw token only in the email, digest in DB" do
    enable_delivery!
    subscribe("Reader@Example.com ")
    assert_response :accepted
    assert_equal 1, ActionMailer::Base.deliveries.size
    mail = ActionMailer::Base.deliveries.last
    assert_equal ["reader@example.com"], mail.to
    assert_equal ["reply@site.test"], mail.reply_to
    assert_equal "Confirm your Throne Tech email subscription", mail.subject
    token = token_from_last_mail
    assert token
    assert_includes mail.html_part.body.to_s, "https://site.test/newsletter#confirm=#{token}"
    sub = NewsletterSubscriber.sole
    assert_equal Digest::SHA256.hexdigest(token), sub.confirm_token_digest
    refute(sub.attributes.values.any? { |v| v.to_s.include?(token) })
    assert_equal "accepted_by_provider", sub.last_confirmation_status

    post "/api/v1/newsletter/confirmations", params: { token: token }, as: :json
    assert_response :ok
    assert_equal "subscribed", response.parsed_body["status"]
    sub.reload
    assert_equal "subscribed", sub.status
    assert sub.consented_at
    assert_nil sub.confirm_token_digest

    post "/api/v1/newsletter/confirmations", params: { token: token }, as: :json
    assert_response :gone # single use
  end

  test "confirmation tokens expire and garbage tokens are rejected" do
    enable_delivery!
    subscribe
    token = token_from_last_mail
    travel 49.hours
    post "/api/v1/newsletter/confirmations", params: { token: token }, as: :json
    assert_response :gone
    post "/api/v1/newsletter/confirmations", params: { token: "short" }, as: :json
    assert_response :gone
    assert_equal "pending", NewsletterSubscriber.sole.status
  end

  test "responses are identical for new, pending, subscribed and unsubscribed addresses" do
    enable_delivery!
    bodies = []
    subscribe("a@example.com"); bodies << [response.status, response.body]
    subscribe("a@example.com"); bodies << [response.status, response.body] # pending, cooldown
    NewsletterSubscriber.create!(email: "s@example.com", status: "subscribed")
    subscribe("s@example.com"); bodies << [response.status, response.body]
    NewsletterSubscriber.create!(email: "u@example.com", status: "unsubscribed")
    subscribe("u@example.com"); bodies << [response.status, response.body]
    assert_equal 1, bodies.uniq.size
    assert_equal 202, bodies.first.first
    # Only the new address and the unsubscribed (re-opt-in) address got mail.
    assert_equal %w[a@example.com u@example.com], ActionMailer::Base.deliveries.map { |m| m.to.first }.sort
    assert_equal "unsubscribed", NewsletterSubscriber.find_by(email: "u@example.com").status
  end

  test "resend cooldown, rotation and daily cap" do
    enable_delivery!
    subscribe
    first = token_from_last_mail
    subscribe
    assert_equal 1, ActionMailer::Base.deliveries.size # 10-minute cooldown
    travel 11.minutes
    subscribe
    assert_equal 2, ActionMailer::Base.deliveries.size
    post "/api/v1/newsletter/confirmations", params: { token: first }, as: :json
    assert_response :gone # rotated
    travel 11.minutes
    subscribe
    travel 11.minutes
    subscribe
    assert_equal 3, ActionMailer::Base.deliveries.size # max 3 per 24h
    assert_equal "cooldown", NewsletterSubscriber.sole.last_confirmation_status
  end

  test "provider failure is recorded and the response is unchanged" do
    enable_delivery!
    failing = Object.new
    def failing.deliver_now = raise(StandardError, "provider down")
    mailer = Object.new
    mailer.define_singleton_method(:confirm_subscription) { failing }
    NewsletterMailer.stub(:with, ->(**) { mailer }) { subscribe }
    assert_response :accepted
    assert_equal "failed", NewsletterSubscriber.sole.last_confirmation_status
  end

  # --- input handling -----------------------------------------------------------
  test "validation, consent and honeypot" do
    enable_signup!
    post "/api/v1/newsletter/subscriptions", params: { email: "nope", consent: true }, as: :json
    assert_response :unprocessable_entity
    post "/api/v1/newsletter/subscriptions", params: { email: "x@example.com" }, as: :json
    assert_response :unprocessable_entity
    subscribe("bot@example.com", website: "spam")
    assert_response :accepted
    assert_equal 0, NewsletterSubscriber.count
  end

  test "attribution allowlist and slug are kept through confirmation; junk is dropped" do
    enable_delivery!
    subscribe("a@example.com", utm_source: "FB", utm_campaign: "Spring-Launch")
    token = token_from_last_mail
    post "/api/v1/newsletter/confirmations", params: { token: token }, as: :json
    sub = NewsletterSubscriber.find_by(email: "a@example.com")
    assert_equal ["subscribed", "facebook", "spring-launch"], [sub.status, sub.source, sub.campaign]
    subscribe("b@example.com", utm_source: "google", utm_campaign: "bad slug!<script>")
    sub = NewsletterSubscriber.find_by(email: "b@example.com")
    assert_nil sub.source
    assert_nil sub.campaign
  end

  # --- unsubscribe --------------------------------------------------------------
  test "page unsubscribe works without login, is idempotent, and works while signup is off" do
    sub = NewsletterSubscriber.create!(email: "r@example.com", status: "subscribed")
    post "/api/v1/newsletter/unsubscribe", params: { token: sub.unsubscribe_token }, as: :json
    assert_response :ok
    assert_equal ["unsubscribed", "page"], sub.reload.then { |s| [s.status, s.unsubscribe_method] }
    post "/api/v1/newsletter/unsubscribe", params: { token: sub.unsubscribe_token }, as: :json
    assert_response :ok
    post "/api/v1/newsletter/unsubscribe", params: { token: "forged" }, as: :json
    assert_response :not_found
  end

  test "RFC 8058 one-click unsubscribe accepts a form POST and always returns 200" do
    sub = NewsletterSubscriber.create!(email: "o@example.com", status: "subscribed")
    post "/api/v1/newsletter/unsubscribe/one_click?token=#{CGI.escape(sub.unsubscribe_token)}",
         params: "List-Unsubscribe=One-Click", headers: { "CONTENT_TYPE" => "application/x-www-form-urlencoded" }
    assert_response :ok
    assert_equal ["unsubscribed", "one_click"], sub.reload.then { |s| [s.status, s.unsubscribe_method] }
    post "/api/v1/newsletter/unsubscribe/one_click?token=forged", params: "List-Unsubscribe=One-Click",
         headers: { "CONTENT_TYPE" => "application/x-www-form-urlencoded" }
    assert_response :ok
  end

  test "unsubscribing cancels a pending re-opt-in token" do
    enable_delivery!
    sub = NewsletterSubscriber.create!(email: "u@example.com", status: "unsubscribed", unsubscribed_at: 1.day.ago)
    subscribe("u@example.com")
    token = token_from_last_mail
    post "/api/v1/newsletter/unsubscribe", params: { token: sub.unsubscribe_token }, as: :json
    post "/api/v1/newsletter/confirmations", params: { token: token }, as: :json
    assert_response :gone
    assert_equal "unsubscribed", sub.reload.status
  end

  # --- abuse throttles ----------------------------------------------------------
  test "rack-attack limits subscribe per IP and per address" do
    enable_signup!
    Rack::Attack.enabled = true
    5.times { |i| subscribe("ip#{i}@example.com") }
    subscribe("ip5@example.com")
    assert_response :too_many_requests
    Rack::Attack.cache.store.clear
    4.times do |i| # rotating IPs, same address
      post "/api/v1/newsletter/subscriptions", params: { email: "Same@example.com", consent: true }, as: :json,
           env: { "REMOTE_ADDR" => "203.0.113.#{i + 1}" }
      assert_response(i < 3 ? :accepted : :too_many_requests)
    end
  ensure
    Rack::Attack.enabled = false
  end
end
