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
