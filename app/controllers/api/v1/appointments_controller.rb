# frozen_string_literal: true

module Api
  module V1
    class AppointmentsController < ApplicationController
      def slots
        from_time, to_time = parse_range_params
        return if performed?

        slots = Appointments::SlotGenerator.new.available_starts(from_time: from_time, to_time: to_time)
        render json: { slots: slots, timezone: AppointmentSetting.instance.timezone }
      rescue ArgumentError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def create
        starts_at = parse_starts_at(appointment_params[:starts_at])
        return if performed?

        settings = AppointmentSetting.instance
        generator = Appointments::SlotGenerator.new(settings: settings)
        unless generator.available?(starts_at)
          render json: { errors: ["Selected slot is no longer available"] }, status: :unprocessable_entity
          return
        end

        appointment = Appointment.new(
          name: appointment_params[:name],
          email: appointment_params[:email],
          company: appointment_params[:company],
          notes: appointment_params[:notes],
          starts_at: starts_at,
          duration_minutes: settings.slot_duration_minutes,
          status: "pending"
        )

        if appointment.save
          render json: { appointment: appointment_json(appointment) }, status: :created
        else
          render json: { errors: appointment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def show_reschedule
        appointment = Appointment.find_by_valid_reschedule_token(params[:token])
        unless appointment
          render json: { error: "Invalid or expired reschedule token" }, status: :not_found
          return
        end

        render json: {
          appointment: appointment_json(appointment).slice(:id, :name, :email, :company, :notes, :starts_at, :duration_minutes, :status),
          timezone: AppointmentSetting.instance.timezone
        }
      end

      def update_reschedule
        appointment = Appointment.find_by_valid_reschedule_token(params[:token])
        unless appointment
          render json: { error: "Invalid or expired reschedule token" }, status: :not_found
          return
        end

        starts_at = parse_starts_at(reschedule_params[:starts_at])
        return if performed?

        settings = AppointmentSetting.instance
        generator = Appointments::SlotGenerator.new(
          settings: settings,
          exclude_appointment_id: appointment.id
        )
        unless generator.available?(starts_at)
          render json: { errors: ["Selected slot is no longer available"] }, status: :unprocessable_entity
          return
        end

        if appointment.update(
          starts_at: starts_at,
          duration_minutes: settings.slot_duration_minutes,
          status: "pending",
          reschedule_token: nil,
          reschedule_token_expires_at: nil
        )
          render json: { appointment: appointment_json(appointment) }
        else
          render json: { errors: appointment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def appointment_params
        params.require(:appointment).permit(:name, :email, :company, :notes, :starts_at)
      end

      def reschedule_params
        params.require(:appointment).permit(:starts_at)
      end

      def parse_range_params
        unless params[:from].present? && params[:to].present?
          render json: { error: "from and to are required" }, status: :unprocessable_entity
          return [nil, nil]
        end

        from_time = Time.iso8601(params[:from].to_s)
        to_time = Time.iso8601(params[:to].to_s)
        [from_time, to_time]
      rescue ArgumentError
        render json: { error: "from and to must be ISO8601 timestamps" }, status: :unprocessable_entity
        [nil, nil]
      end

      def parse_starts_at(value)
        if value.blank?
          render json: { errors: ["starts_at is required"] }, status: :unprocessable_entity
          return
        end

        Time.iso8601(value.to_s)
      rescue ArgumentError
        render json: { errors: ["starts_at must be an ISO8601 timestamp"] }, status: :unprocessable_entity
        nil
      end

      def appointment_json(appointment)
        {
          id: appointment.id,
          name: appointment.name,
          email: appointment.email,
          company: appointment.company,
          notes: appointment.notes,
          starts_at: appointment.starts_at.utc.iso8601,
          duration_minutes: appointment.duration_minutes,
          status: appointment.status,
          created_at: appointment.created_at.iso8601,
          updated_at: appointment.updated_at.iso8601
        }
      end
    end
  end
end
