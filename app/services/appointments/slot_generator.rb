# frozen_string_literal: true

module Appointments
  class SlotGenerator
    WEEKDAY_KEYS = {
      0 => "sun",
      1 => "mon",
      2 => "tue",
      3 => "wed",
      4 => "thu",
      5 => "fri",
      6 => "sat"
    }.freeze

    def initialize(settings: AppointmentSetting.instance, exclude_appointment_id: nil)
      @settings = settings
      @exclude_appointment_id = exclude_appointment_id
      @zone = Time.find_zone!(settings.timezone)
    end

    # Returns ISO8601 UTC starts for available slots in [from_time, to_time].
    def available_starts(from_time:, to_time:)
      from_time = from_time.to_time.utc
      to_time = to_time.to_time.utc
      raise ArgumentError, "from must be before to" if from_time >= to_time

      earliest = Time.current.utc + @settings.lead_time_hours.hours
      latest = Time.current.utc + @settings.bookable_days_ahead.days
      window_start = [from_time, earliest].max
      window_end = [to_time, latest].min
      return [] if window_start >= window_end

      booked = blocking_appointments(window_start, window_end)
      duration = @settings.slot_duration_minutes.minutes
      slots = []

      each_local_day(window_start, window_end) do |local_date|
        day_config = day_hours_for(local_date)
        next unless truthy?(day_config["enabled"] || day_config[:enabled])

        day_start = parse_local_time(local_date, day_config["start"] || day_config[:start])
        day_end = parse_local_time(local_date, day_config["end"] || day_config[:end])
        next if day_start.nil? || day_end.nil? || day_start >= day_end

        cursor = day_start
        while cursor + duration <= day_end
          utc_start = cursor.utc
          utc_end = (cursor + duration).utc
          if utc_start >= window_start && utc_start < window_end && !overlaps_any?(booked, utc_start, utc_end)
            slots << utc_start.iso8601
          end
          cursor += duration
        end
      end

      slots
    end

    def available?(starts_at)
      target = starts_at.to_time.utc
      available_starts(
        from_time: target,
        to_time: target + @settings.slot_duration_minutes.minutes
      ).any? { |iso| Time.iso8601(iso).to_i == target.to_i }
    end

    private

    def blocking_appointments(window_start, window_end)
      # Widen fetch window so appointments that started before window_start can still overlap.
      fetch_from = window_start - @settings.slot_duration_minutes.minutes
      scope = Appointment.blocking.where(starts_at: fetch_from..window_end)
      scope = scope.where.not(id: @exclude_appointment_id) if @exclude_appointment_id
      scope.to_a
    end

    def overlaps_any?(appointments, utc_start, utc_end)
      appointments.any? { |appt| appt.overlaps?(utc_start, utc_end) }
    end

    def each_local_day(window_start, window_end)
      local_start = @zone.at(window_start).to_date
      local_end = @zone.at(window_end - 1.second).to_date
      (local_start..local_end).each { |date| yield date }
    end

    def day_hours_for(local_date)
      key = WEEKDAY_KEYS.fetch(local_date.wday)
      raw = @settings.weekly_hours[key] || @settings.weekly_hours[key.to_sym] || {}
      raw.is_a?(Hash) ? raw.stringify_keys : {}
    end

    def parse_local_time(local_date, hhmm)
      return if hhmm.blank?

      hour, minute = hhmm.to_s.split(":").map(&:to_i)
      @zone.local(local_date.year, local_date.month, local_date.day, hour, minute)
    rescue ArgumentError
      nil
    end

    def truthy?(value)
      value == true || value.to_s == "true"
    end
  end
end
