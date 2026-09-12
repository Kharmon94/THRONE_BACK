# frozen_string_literal: true

class CreateAppointmentDateOverrides < ActiveRecord::Migration[8.0]
  def change
    return if table_exists?(:appointment_date_overrides)

    create_table :appointment_date_overrides do |t|
      t.date :date, null: false
      t.boolean :enabled, null: false, default: true
      t.string :start, null: false, default: "10:00"
      t.string :end, null: false, default: "16:00"
      t.timestamps
    end

    add_index :appointment_date_overrides, :date, unique: true
  end
end
