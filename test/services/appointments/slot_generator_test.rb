# frozen_string_literal: true

require "test_helper"

class Appointments::SlotGeneratorTest < ActiveSupport::TestCase
  setup do
    AppointmentSetting.delete_all
    Appointment.delete_all
    @settings = AppointmentSetting.seed_from_yaml!
    @settings.update!(lead_time_hours: 0, bookable_days_ahead: 14)
    travel_to Time.find_zone!("America/New_York").local(2026, 3, 16, 9, 0, 0)
  end

  teardown do
    travel_back
  end

  test "respects weekly hours from DB settings" do
    @settings.update!(
      weekly_hours: @settings.weekly_hours.merge(
        "mon" => { "enabled" => true, "start" => "13:00", "end" => "14:00" }
      )
    )

    from = Time.find_zone!("America/New_York").local(2026, 3, 16, 0, 0, 0)
    to = Time.find_zone!("America/New_York").local(2026, 3, 17, 0, 0, 0)
    slots = Appointments::SlotGenerator.new(settings: @settings.reload).available_starts(from_time: from, to_time: to)

    assert_equal 2, slots.size
    hours = slots.map { |s| Time.iso8601(s).in_time_zone("America/New_York").hour }
    assert_equal [13, 13], hours
    assert_equal [0, 30], slots.map { |s| Time.iso8601(s).in_time_zone("America/New_York").min }
  end

  test "available? is false for past lead window" do
    @settings.update!(lead_time_hours: 24)
    travel_to Time.find_zone!("America/New_York").local(2026, 3, 16, 12, 0, 0)

    too_soon = Time.find_zone!("America/New_York").local(2026, 3, 16, 15, 0, 0)
    refute Appointments::SlotGenerator.new(settings: @settings.reload).available?(too_soon)
  end
end
