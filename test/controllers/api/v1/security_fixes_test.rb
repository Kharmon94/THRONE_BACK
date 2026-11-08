# frozen_string_literal: true

require "test_helper"

# Regression tests for the Nov 2026 review fixes.
class SecurityFixesRequestTest < ActionDispatch::IntegrationTest
  ZONE = Time.find_zone!("America/New_York")

  setup do
    AppointmentSetting.delete_all
    Appointment.delete_all
    AppointmentDateOverride.delete_all
    @settings = AppointmentSetting.seed_from_yaml!
    @settings.update!(lead_time_hours: 0, bookable_days_ahead: 14)
    travel_to ZONE.local(2026, 3, 16, 9, 0, 0) # Monday
    @admin = users(:admin)
  end

  teardown do
    travel_back
    ENV.delete("ALLOW_PUBLIC_SIGN_UP")
  end

  def book!(status: "confirmed", hour: 10)
    Appointment.create!(name: "Ada", email: "ada@example.com",
                        starts_at: ZONE.local(2026, 3, 16, hour, 0, 0),
                        duration_minutes: 30, status: status)
  end

  # --- bootstrap admin -----------------------------------------------------
  test "sign_up on an empty users table is forbidden and grants nothing" do
    Project.update_all(user_id: nil)
    User.delete_all
    assert_no_difference("User.count") do
      post "/api/v1/auth/sign_up",
           params: { user: { email: "first@throne.test", password: "password123", password_confirmation: "password123" } },
           as: :json
    end
    assert_response :forbidden
  end

  test "explicitly enabled sign_up never creates an admin" do
    ENV["ALLOW_PUBLIC_SIGN_UP"] = "true"
    Project.update_all(user_id: nil)
    User.delete_all
    post "/api/v1/auth/sign_up",
         params: { user: { email: "first@throne.test", password: "password123", password_confirmation: "password123" } },
         as: :json
    assert_response :created
    assert_equal false, JSON.parse(response.body)["user"]["admin"]
    assert_equal false, User.find_by(email: "first@throne.test").admin?
  end

  # --- status resurrection ---------------------------------------------------
  test "cancelling clears the reschedule token so the old link is dead" do
    appt = book!
    appt.mint_reschedule_token!
    token = appt.reschedule_token

    patch "/api/v1/admin/appointments/#{appt.id}", headers: auth_headers(@admin),
          params: { appointment: { status: "cancelled" } }, as: :json
    assert_response :success
    assert_nil appt.reload.reschedule_token

    patch "/api/v1/appointments/reschedule/#{token}",
          params: { appointment: { starts_at: ZONE.local(2026, 3, 16, 14, 0, 0).utc.iso8601 } }, as: :json
    assert_response :not_found
    assert_equal "cancelled", appt.reload.status
  end

  test "a still-valid token on a declined booking cannot revive it" do
    appt = book!(status: "declined")
    # Simulate legacy data minted before the clear-on-decline callback existed.
    appt.update_columns(reschedule_token: "legacy-token", reschedule_token_expires_at: 1.day.from_now)

    get "/api/v1/appointments/reschedule/legacy-token"
    assert_response :not_found
    patch "/api/v1/appointments/reschedule/legacy-token",
          params: { appointment: { starts_at: ZONE.local(2026, 3, 16, 14, 0, 0).utc.iso8601 } }, as: :json
    assert_response :not_found
    assert_equal "declined", appt.reload.status
  end

  test "admin cannot mint a reschedule link for a cancelled booking" do
    appt = book!(status: "cancelled")
    assert_no_emails do
      post "/api/v1/admin/appointments/#{appt.id}/reschedule", headers: auth_headers(@admin), as: :json
    end
    assert_response :unprocessable_entity
    assert_nil appt.reload.reschedule_token
  end

  test "reschedule token can only be used once" do
    appt = book!
    appt.mint_reschedule_token!
    token = appt.reschedule_token
    patch "/api/v1/appointments/reschedule/#{token}",
          params: { appointment: { starts_at: ZONE.local(2026, 3, 16, 14, 0, 0).utc.iso8601 } }, as: :json
    assert_response :success
    patch "/api/v1/appointments/reschedule/#{token}",
          params: { appointment: { starts_at: ZONE.local(2026, 3, 16, 15, 0, 0).utc.iso8601 } }, as: :json
    assert_response :not_found
  end

  test "reschedule cannot move onto a slot another client already holds" do
    book!(status: "pending", hour: 14)
    appt = book!(hour: 10)
    appt.mint_reschedule_token!
    patch "/api/v1/appointments/reschedule/#{appt.reschedule_token}",
          params: { appointment: { starts_at: ZONE.local(2026, 3, 16, 14, 0, 0).utc.iso8601 } }, as: :json
    assert_response :unprocessable_entity
    assert_equal 10, appt.reload.starts_at.in_time_zone(ZONE).hour
  end

  # --- email delivery reporting ----------------------------------------------
  test "reschedule email failure is reported and no live link is left behind" do
    appt = book!
    failing = Object.new
    def failing.deliver_now = raise(StandardError, "provider down")
    mailer = Object.new
    mailer.define_singleton_method(:reschedule_instructions) { failing }
    original = AppointmentMailer.method(:with)
    AppointmentMailer.define_singleton_method(:with) { |*_args, **_kw| mailer }
    begin
      post "/api/v1/admin/appointments/#{appt.id}/reschedule", headers: auth_headers(@admin), as: :json
    ensure
      AppointmentMailer.define_singleton_method(:with, original)
    end
    assert_response :bad_gateway
    body = JSON.parse(response.body)
    assert_equal false, body["reschedule_sent"]
    assert_equal "failed", body["email_status"]
    assert_nil appt.reload.reschedule_token
  end

  test "reschedule email shows times in the business timezone" do
    appt = book!
    appt.mint_reschedule_token!
    mail = AppointmentMailer.with(appointment: appt).reschedule_instructions
    text = mail.text_part.body.to_s
    assert_includes text, "Monday, March 16, 2026 at 10:00 AM EDT"
    refute_includes text, "UTC"
    assert_includes mail.html_part.body.to_s, "10:00 AM EDT"
  end

  # --- input validation --------------------------------------------------------
  test "public booking rejects oversized fields" do
    post "/api/v1/appointments",
         params: { appointment: { name: "A" * 500, email: "ada@example.com",
                                  starts_at: ZONE.local(2026, 3, 16, 10, 30, 0).utc.iso8601 } },
         as: :json
    assert_response :unprocessable_entity
    assert_equal 0, Appointment.count
  end

  test "project links must be http(s)" do
    post "/api/v1/admin/projects", headers: auth_headers(@admin),
         params: { project: { title: "X", live_url: "javascript:alert(1)" } }, as: :json
    assert_response :unprocessable_entity

    post "/api/v1/admin/projects", headers: auth_headers(@admin),
         params: { project: { title: "X", live_url: "https://example.com", github_url: "http://github.com/a/b" } },
         as: :json
    assert_response :created
  end

  test "project image upload rejects SVG" do
    svg = Rack::Test::UploadedFile.new(StringIO.new("<svg xmlns='http://www.w3.org/2000/svg'><script/></svg>"),
                                       "image/svg+xml", original_filename: "x.svg")
    post "/api/v1/admin/projects",
         headers: { "Authorization" => auth_headers(@admin)["Authorization"] },
         params: { project: { title: "SVG", image: svg } }
    assert_response :unprocessable_entity
  end

  # --- tokens --------------------------------------------------------------------
  test "unsigned (alg none) tokens are rejected" do
    token = JWT.encode({ user_id: @admin.id, exp: 1.hour.from_now.to_i }, nil, "none")
    get "/api/v1/auth/me", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :unauthorized
  end

  test "JWT_REVOKED_BEFORE invalidates older tokens" do
    headers = auth_headers(@admin)
    ENV["JWT_REVOKED_BEFORE"] = 1.minute.from_now.iso8601
    get "/api/v1/auth/me", headers: headers
    assert_response :unauthorized
  ensure
    ENV.delete("JWT_REVOKED_BEFORE")
  end
end
