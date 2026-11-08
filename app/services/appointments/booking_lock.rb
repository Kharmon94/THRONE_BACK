# frozen_string_literal: true

module Appointments
  # Serializes "is this slot free?" + "save the appointment" so two concurrent
  # requests cannot both book the same slot.
  #
  # PostgreSQL (production): SELECT ... FOR UPDATE on the appointment_settings
  # singleton row. Every booking/reschedule takes the same row lock, so the
  # availability check and the insert/update run one at a time. Volume is low
  # (a handful of bookings per day), so a single global lock is acceptable.
  #
  # SQLite (dev/test): Rails 8 opens IMMEDIATE transactions, which already
  # serialize writers; the FOR UPDATE clause is ignored by the adapter.
  module BookingLock
    module_function

    def with_lock
      ActiveRecord::Base.transaction do
        settings = AppointmentSetting.instance
        settings = AppointmentSetting.lock.find(settings.id)
        yield settings
      end
    end
  end
end
