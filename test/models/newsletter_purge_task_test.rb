# frozen_string_literal: true

require "test_helper"
require "rake"

class NewsletterPurgeTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == "newsletter:purge_pending" }
    @saved = ENV["NEWSLETTER_PENDING_RETENTION_DAYS"]
    NewsletterSubscriber.delete_all
  end

  teardown do
    @saved.nil? ? ENV.delete("NEWSLETTER_PENDING_RETENTION_DAYS") : ENV["NEWSLETTER_PENDING_RETENTION_DAYS"] = @saved
    Rake::Task["newsletter:purge_pending"].reenable
  end

  test "refuses to delete anything without a retention setting" do
    ENV.delete("NEWSLETTER_PENDING_RETENTION_DAYS")
    NewsletterSubscriber.create!(email: "old@example.com", status: "pending", requested_at: 1.year.ago)
    assert_raises(SystemExit) { capture_io { Rake::Task["newsletter:purge_pending"].invoke } }
    assert_equal 1, NewsletterSubscriber.count
  end

  test "deletes only expired pending signups" do
    ENV["NEWSLETTER_PENDING_RETENTION_DAYS"] = "30"
    NewsletterSubscriber.create!(email: "old@example.com", status: "pending", requested_at: 31.days.ago)
    NewsletterSubscriber.create!(email: "new@example.com", status: "pending", requested_at: 1.day.ago)
    NewsletterSubscriber.create!(email: "sub@example.com", status: "subscribed", requested_at: 1.year.ago)
    capture_io { Rake::Task["newsletter:purge_pending"].invoke }
    assert_equal %w[new@example.com sub@example.com], NewsletterSubscriber.order(:email).pluck(:email)
  end
end

class NewsletterRetentionTest < ActionDispatch::IntegrationTest
  setup do
    @saved = ENV["NEWSLETTER_PENDING_RETENTION_DAYS"]
    NewsletterSubscriber.delete_all
    Newsletter::Retention.reset!
  end

  teardown do
    @saved.nil? ? ENV.delete("NEWSLETTER_PENDING_RETENTION_DAYS") : ENV["NEWSLETTER_PENDING_RETENTION_DAYS"] = @saved
    Newsletter::Retention.reset!
    travel_back
  end

  test "newsletter traffic purges expired pending signups automatically, at most hourly" do
    ENV["NEWSLETTER_PENDING_RETENTION_DAYS"] = "7"
    NewsletterSubscriber.create!(email: "old@example.com", status: "pending", requested_at: 8.days.ago)
    NewsletterSubscriber.create!(email: "fresh@example.com", status: "pending", requested_at: 6.days.ago)
    NewsletterSubscriber.create!(email: "sub@example.com", status: "subscribed", requested_at: 1.year.ago)
    get "/api/v1/newsletter/config" # works even while signup is closed
    assert_equal %w[fresh@example.com sub@example.com], NewsletterSubscriber.order(:email).pluck(:email)

    NewsletterSubscriber.create!(email: "old2@example.com", status: "pending", requested_at: 8.days.ago)
    get "/api/v1/newsletter/config"
    assert NewsletterSubscriber.exists?(email: "old2@example.com"), "throttled: no second purge within the hour"
    travel 61.minutes
    get "/api/v1/newsletter/config"
    refute NewsletterSubscriber.exists?(email: "old2@example.com")
  end

  test "no retention setting means no automatic deletion" do
    ENV.delete("NEWSLETTER_PENDING_RETENTION_DAYS")
    NewsletterSubscriber.create!(email: "old@example.com", status: "pending", requested_at: 1.year.ago)
    get "/api/v1/newsletter/config"
    assert_equal 1, NewsletterSubscriber.count
  end
end

class RequestLogRedactionTest < ActiveSupport::TestCase
  test "request logs filter personal data and tokens" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    params = { "email" => "a@example.com", "token" => "abc", "consent" => true, "utm_source" => "blog",
               "appointment" => { "name" => "Ada", "email" => "a@example.com", "notes" => "x", "company" => "Co" },
               "user" => { "password" => "pw" } }
    out = filter.filter(params)
    assert_equal "[FILTERED]", out["email"]
    assert_equal "[FILTERED]", out["token"]
    assert_equal %w[[FILTERED]] * 4, out["appointment"].values_at("name", "email", "notes", "company")
    assert_equal "[FILTERED]", out["user"]["password"]
    assert_equal true, out["consent"]
    assert_equal "blog", out["utm_source"]
  end

  test "the one-click query token is filtered from the logged path" do
    env = Rack::MockRequest.env_for("/api/v1/newsletter/unsubscribe/one_click?token=SECRET123").merge(Rails.application.env_config)
    req = ActionDispatch::Request.new(env)
    assert_includes req.filtered_path, "token=[FILTERED]"
    refute_includes req.filtered_path, "SECRET123"
  end
end
