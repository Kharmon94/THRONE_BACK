# frozen_string_literal: true

require "test_helper"

class AppointmentDateOverrideTest < ActiveSupport::TestCase
  test "requires end after start when enabled" do
    override = AppointmentDateOverride.new(
      date: Date.new(2026, 3, 16),
      enabled: true,
      start: "16:00",
      end: "10:00"
    )
    refute override.valid?
    assert_includes override.errors[:end], "must be after start"
  end

  test "allows closed day without end-after-start check" do
    override = AppointmentDateOverride.new(
      date: Date.new(2026, 3, 16),
      enabled: false,
      start: "16:00",
      end: "10:00"
    )
    assert override.valid?
  end

  test "enforces unique date" do
    AppointmentDateOverride.create!(
      date: Date.new(2026, 3, 16),
      enabled: true,
      start: "10:00",
      end: "16:00"
    )
    dup = AppointmentDateOverride.new(
      date: Date.new(2026, 3, 16),
      enabled: false,
      start: "09:00",
      end: "12:00"
    )
    refute dup.valid?
    assert_includes dup.errors[:date], "has already been taken"
  end
end
