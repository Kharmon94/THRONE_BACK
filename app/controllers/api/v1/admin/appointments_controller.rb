# frozen_string_literal: true

module Api
  module V1
    module Admin
      class AppointmentsController < BaseController
        before_action :set_appointment, only: [:update, :destroy, :reschedule]

        def index
          authorize! :read, Appointment
          appointments = Appointment.ordered
          if params[:from].present? && params[:to].present?
            from_time = Time.iso8601(params[:from].to_s)
            to_time = Time.iso8601(params[:to].to_s)
            appointments = appointments.in_window(from_time, to_time)
          end
          render json: { appointments: appointments.map { |a| appointment_json(a) } }
        rescue ArgumentError
          render json: { error: "from and to must be ISO8601 timestamps" }, status: :unprocessable_entity
        end

        def update
          authorize! :update, @appointment
          unless Appointment::STATUSES.include?(status_params[:status].to_s)
            render json: { errors: ["status must be one of: #{Appointment::STATUSES.join(', ')}"] },
                   status: :unprocessable_entity
            return
          end

          if @appointment.update(status: status_params[:status])
            render json: { appointment: appointment_json(@appointment) }
          else
            render json: { errors: @appointment.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          authorize! :destroy, @appointment
          @appointment.destroy
          head :no_content
        end

        def reschedule
          authorize! :update, @appointment
          @appointment.mint_reschedule_token!
          AppointmentMailer.with(appointment: @appointment).reschedule_instructions.deliver_later
          render json: {
            appointment: appointment_json(@appointment),
            reschedule_sent: true
          }
        end

        private

        def set_appointment
          @appointment = Appointment.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Not found" }, status: :not_found
        end

        def status_params
          params.require(:appointment).permit(:status)
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
            reschedule_token_expires_at: appointment.reschedule_token_expires_at&.utc&.iso8601,
            created_at: appointment.created_at.iso8601,
            updated_at: appointment.updated_at.iso8601
          }
        end
      end
    end
  end
end
