# frozen_string_literal: true

require "test_helper"

class AppointmentsRequestTest < ActionDispatch::IntegrationTest
  setup do
    AppointmentSetting.delete_all
    Appointment.delete_all
    AppointmentDateOverride.delete_all
    @settings = AppointmentSetting.seed_from_yaml!
    # Make slots immediately bookable in tests.
    @settings.update!(lead_time_hours: 0, bookable_days_ahead: 14)
    travel_to Time.find_zone!("America/New_York").local(2026, 3, 16, 9, 0, 0) # Monday
  end

  teardown do
    travel_back
  end

  test "slots returns available starts for open weekdays" do
    from = Time.find_zone!("America/New_York").local(2026, 3, 16, 0, 0, 0).utc.iso8601
    to = Time.find_zone!("America/New_York").local(2026, 3, 17, 0, 0, 0).utc.iso8601

    get "/api/v1/appointments/slots", params: { from: from, to: to }

    assert_response :success
    body = JSON.parse(response.body)
    assert body["slots"].any?
    assert_equal "America/New_York", body["timezone"]
    # First slot should be 10:00 MT
    first = Time.iso8601(body["slots"].first)
    assert_equal 10, first.in_time_zone("America/New_York").hour
    assert_equal 0, first.in_time_zone("America/New_York").min
  end

  test "slots exclude booked pending appointments" do
    starts = Time.find_zone!("America/New_York").local(2026, 3, 16, 10, 0, 0)
    Appointment.create!(
      name: "Booked",
      email: "booked@example.com",
      starts_at: starts,
      duration_minutes: 30,
      status: "pending"
    )

    from = Time.find_zone!("America/New_York").local(2026, 3, 16, 0, 0, 0).utc.iso8601
    to = Time.find_zone!("America/New_York").local(2026, 3, 17, 0, 0, 0).utc.iso8601
    get "/api/v1/appointments/slots", params: { from: from, to: to }

    assert_response :success
    slots = JSON.parse(response.body)["slots"]
    refute_includes slots, starts.utc.iso8601
  end

  test "create books an available slot" do
    starts = Time.find_zone!("America/New_York").local(2026, 3, 16, 10, 30, 0)

    assert_difference("Appointment.count", 1) do
      post "/api/v1/appointments",
           params: {
             appointment: {
               name: "Ada",
               email: "ada@example.com",
               company: "Analytical",
               notes: "Chat about a build",
               starts_at: starts.utc.iso8601
             }
           },
           as: :json
    end

    assert_response :created
    body = JSON.parse(response.body)["appointment"]
    assert_equal "pending", body["status"]
    assert_equal 30, body["duration_minutes"]
  end

  test "create rejects taken slot" do
    starts = Time.find_zone!("America/New_York").local(2026, 3, 16, 11, 0, 0)
    Appointment.create!(
      name: "Taken",
      email: "taken@example.com",
      starts_at: starts,
      duration_minutes: 30,
      status: "confirmed"
    )

    post "/api/v1/appointments",
         params: {
           appointment: {
             name: "Ada",
             email: "ada@example.com",
             starts_at: starts.utc.iso8601
           }
         },
         as: :json

    assert_response :unprocessable_entity
  end

  test "settings patch changes available slots" do
    admin = users(:admin)
    patch "/api/v1/admin/appointment_settings",
          headers: auth_headers(admin),
          params: {
            appointment_settings: {
              weekly_hours: {
                mon: { enabled: false, start: "10:00", end: "16:00" },
                tue: { enabled: true, start: "10:00", end: "16:00" },
                wed: { enabled: true, start: "10:00", end: "16:00" },
                thu: { enabled: true, start: "10:00", end: "16:00" },
                fri: { enabled: true, start: "10:00", end: "16:00" },
                sat: { enabled: false, start: "10:00", end: "16:00" },
                sun: { enabled: false, start: "10:00", end: "16:00" }
              }
            }
          },
          as: :json

    assert_response :success

    from = Time.find_zone!("America/New_York").local(2026, 3, 16, 0, 0, 0).utc.iso8601
    to = Time.find_zone!("America/New_York").local(2026, 3, 17, 0, 0, 0).utc.iso8601
    get "/api/v1/appointments/slots", params: { from: from, to: to }

    assert_response :success
    assert_empty JSON.parse(response.body)["slots"]
  end

  test "admin reschedule mints token and client can reschedule" do
    admin = users(:admin)
    starts = Time.find_zone!("America/New_York").local(2026, 3, 16, 10, 0, 0)
    appointment = Appointment.create!(
      name: "Ada",
      email: "ada@example.com",
      starts_at: starts,
      duration_minutes: 30,
      status: "confirmed"
    )

    assert_enqueued_emails 1 do
      post "/api/v1/admin/appointments/#{appointment.id}/reschedule",
           headers: auth_headers(admin),
           as: :json
    end
    assert_response :success

    appointment.reload
    assert appointment.reschedule_token_valid?

    get "/api/v1/appointments/reschedule/#{appointment.reschedule_token}"
    assert_response :success

    new_starts = Time.find_zone!("America/New_York").local(2026, 3, 16, 14, 0, 0)
    patch "/api/v1/appointments/reschedule/#{appointment.reschedule_token}",
          params: { appointment: { starts_at: new_starts.utc.iso8601 } },
          as: :json

    assert_response :success
    appointment.reload
    assert_equal "pending", appointment.status
    assert_nil appointment.reschedule_token
    assert_equal new_starts.utc.to_i, appointment.starts_at.utc.to_i
  end

  test "expired reschedule token is rejected" do
    appointment = Appointment.create!(
      name: "Ada",
      email: "ada@example.com",
      starts_at: Time.find_zone!("America/New_York").local(2026, 3, 16, 10, 0, 0),
      duration_minutes: 30,
      status: "pending",
      reschedule_token: "expired-token",
      reschedule_token_expires_at: 1.hour.ago
    )

    get "/api/v1/appointments/reschedule/#{appointment.reschedule_token}"
    assert_response :not_found
  end

  test "admin can update status and delete" do
    admin = users(:admin)
    appointment = Appointment.create!(
      name: "Ada",
      email: "ada@example.com",
      starts_at: Time.find_zone!("America/New_York").local(2026, 3, 16, 10, 0, 0),
      duration_minutes: 30,
      status: "pending"
    )

    patch "/api/v1/admin/appointments/#{appointment.id}",
          headers: auth_headers(admin),
          params: { appointment: { status: "confirmed" } },
          as: :json
    assert_response :success
    assert_equal "confirmed", appointment.reload.status

    assert_difference("Appointment.count", -1) do
      delete "/api/v1/admin/appointments/#{appointment.id}", headers: auth_headers(admin)
    end
    assert_response :no_content
  end

  test "admin date overrides CRUD and affect public slots" do
    admin = users(:admin)

    assert_difference("AppointmentDateOverride.count", 1) do
      post "/api/v1/admin/appointment_date_overrides",
           headers: auth_headers(admin),
           params: {
             appointment_date_override: {
               date: "2026-03-16",
               enabled: true,
               start: "14:00",
               end: "15:00"
             }
           },
           as: :json
    end
    assert_response :created
    override_id = JSON.parse(response.body)["appointment_date_override"]["id"]

    from = Time.find_zone!("America/New_York").local(2026, 3, 16, 0, 0, 0).utc.iso8601
    to = Time.find_zone!("America/New_York").local(2026, 3, 17, 0, 0, 0).utc.iso8601
    get "/api/v1/appointments/slots", params: { from: from, to: to }
    assert_response :success
    hours = JSON.parse(response.body)["slots"].map { |s| Time.iso8601(s).in_time_zone("America/New_York").hour }
    assert_equal [14, 14], hours

    patch "/api/v1/admin/appointment_date_overrides/#{override_id}",
          headers: auth_headers(admin),
          params: { appointment_date_override: { enabled: false } },
          as: :json
    assert_response :success

    get "/api/v1/appointments/slots", params: { from: from, to: to }
    assert_empty JSON.parse(response.body)["slots"]

    get "/api/v1/admin/appointment_date_overrides",
        headers: auth_headers(admin),
        params: { from: "2026-03-01", to: "2026-03-31" }
    assert_response :success
    assert_equal 1, JSON.parse(response.body)["appointment_date_overrides"].size

    assert_difference("AppointmentDateOverride.count", -1) do
      delete "/api/v1/admin/appointment_date_overrides/#{override_id}", headers: auth_headers(admin)
    end
    assert_response :no_content
  end
end
