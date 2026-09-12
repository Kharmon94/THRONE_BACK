# frozen_string_literal: true

module Api
  module V1
    module Admin
      class AppointmentDateOverridesController < BaseController
        before_action :set_override, only: [:update, :destroy]

        def index
          authorize! :read, AppointmentDateOverride
          from_date = parse_date(params[:from])
          to_date = parse_date(params[:to])
          overrides = AppointmentDateOverride.in_range(from_date, to_date)
          render json: { appointment_date_overrides: overrides.map(&:as_api_json) }
        end

        def create
          authorize! :create, AppointmentDateOverride
          override = AppointmentDateOverride.new(override_params)
          if override.save
            render json: { appointment_date_override: override.as_api_json }, status: :created
          else
            render json: { errors: override.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def update
          authorize! :update, @override
          if @override.update(override_params)
            render json: { appointment_date_override: @override.as_api_json }
          else
            render json: { errors: @override.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          authorize! :destroy, @override
          @override.destroy
          head :no_content
        end

        private

        def set_override
          @override = AppointmentDateOverride.find(params[:id])
        end

        def override_params
          raw = params.require(:appointment_date_override)
          permitted = raw.permit(:date, :enabled, :start, :end)
          if permitted.key?(:enabled) || raw.key?(:enabled) || raw.key?("enabled")
            permitted[:enabled] = ActiveModel::Type::Boolean.new.cast(
              raw[:enabled].nil? ? raw["enabled"] : raw[:enabled]
            )
          end
          permitted
        end

        def parse_date(value)
          return if value.blank?

          Date.iso8601(value.to_s)
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
