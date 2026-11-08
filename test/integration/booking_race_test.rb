# frozen_string_literal: true

require "test_helper"

# Exercises the booking lock with real concurrent threads/connections.
# Runs against SQLite in test (IMMEDIATE transactions); production uses
# PostgreSQL row locks (SELECT ... FOR UPDATE), which is not exercised here.
class BookingRaceTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false
  ZONE = Time.find_zone!("America/New_York")

  setup do
    Appointment.delete_all
    AppointmentDateOverride.delete_all
    AppointmentSetting.delete_all
    AppointmentSetting.seed_from_yaml!.update!(lead_time_hours: 0, bookable_days_ahead: 14)
  end

  teardown do
    Appointment.delete_all
    AppointmentSetting.delete_all
  end

  def attempt(starts_at, pause:)
    Appointments::BookingLock.with_lock do |settings|
      ok = Appointments::SlotGenerator.new(settings: settings).available?(starts_at)
      sleep pause # widen the check-then-save window
      if ok
        Appointment.create!(name: "T", email: "t@example.com", starts_at: starts_at,
                            duration_minutes: settings.slot_duration_minutes, status: "pending")
      end
      ok
    end
  end

  test "two concurrent bookings for one slot produce exactly one appointment" do
    travel_to ZONE.local(2026, 3, 16, 9, 0, 0) do
      starts_at = ZONE.local(2026, 3, 16, 11, 0, 0)
      results = 2.times.map do
        Thread.new { ActiveRecord::Base.connection_pool.with_connection { attempt(starts_at, pause: 0.3) } }
      end.map(&:value)

      assert_equal [false, true], results.sort_by { |r| r ? 1 : 0 }
      assert_equal 1, Appointment.where(starts_at: starts_at).count
    end
  end

  test "public reschedule and a new booking racing for the same slot cannot both win" do
    travel_to ZONE.local(2026, 3, 16, 9, 0, 0) do
      target = ZONE.local(2026, 3, 16, 13, 0, 0)
      existing = Appointment.create!(name: "R", email: "r@example.com",
                                     starts_at: ZONE.local(2026, 3, 16, 10, 0, 0),
                                     duration_minutes: 30, status: "confirmed")
      reschedule = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Appointments::BookingLock.with_lock do |settings|
            gen = Appointments::SlotGenerator.new(settings: settings, exclude_appointment_id: existing.id)
            ok = gen.available?(target)
            sleep 0.3
            existing.update!(starts_at: target) if ok
            ok
          end
        end
      end
      booking = Thread.new { ActiveRecord::Base.connection_pool.with_connection { attempt(target, pause: 0.3) } }
      outcomes = [reschedule.value, booking.value]

      assert_equal 1, outcomes.count(true)
      assert_equal 1, Appointment.blocking.where(starts_at: target).count
    end
  end
end
