# frozen_string_literal: true

# Updates the column default for new rows only. Does not rewrite existing
# AppointmentSetting records — change those via Admin Hours or console.
class ChangeAppointmentSettingsTimezoneDefault < ActiveRecord::Migration[8.0]
  def change
    change_column_default :appointment_settings, :timezone, from: "America/Denver", to: "America/New_York"
  end
end
