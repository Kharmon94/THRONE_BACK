# frozen_string_literal: true

module Api
  module V1
    module Admin
      class AppointmentSettingsController < BaseController
        def show
          authorize! :read, AppointmentSetting
          render json: { appointment_settings: AppointmentSetting.instance.as_api_json }
        end

        def update
          authorize! :update, AppointmentSetting
          settings = AppointmentSetting.instance
          if settings.update(settings_params)
            render json: { appointment_settings: settings.as_api_json }
          else
            render json: { errors: settings.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def settings_params
          raw = params.require(:appointment_settings)
          permitted = raw.permit(
            :timezone,
            :slot_duration_minutes,
            :lead_time_hours,
            :bookable_days_ahead
          )

          if raw[:weekly_hours].present?
            weekly = raw[:weekly_hours]
            weekly = weekly.to_unsafe_h if weekly.respond_to?(:to_unsafe_h)
            permitted[:weekly_hours] = AppointmentSetting::WEEKDAYS.each_with_object({}) do |day, hash|
              day_hours = weekly[day] || weekly[day.to_sym]
              next unless day_hours

              day_hours = day_hours.to_unsafe_h if day_hours.respond_to?(:to_unsafe_h)
              hash[day] = {
                "enabled" => ActiveModel::Type::Boolean.new.cast(day_hours["enabled"] || day_hours[:enabled]),
                "start" => (day_hours["start"] || day_hours[:start]).to_s,
                "end" => (day_hours["end"] || day_hours[:end]).to_s
              }
            end
          end

          permitted
        end
      end
    end
  end
end
