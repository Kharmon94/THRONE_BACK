# frozen_string_literal: true

class EvolveContactEntriesToAppointments < ActiveRecord::Migration[8.0]
  def up
    if table_exists?(:contact_entries) && !table_exists?(:appointments)
      rename_table :contact_entries, :appointments
    end

    if column_exists?(:appointments, :message)
      rename_column :appointments, :message, :notes
    end

    remove_column :appointments, :budget if column_exists?(:appointments, :budget)

    add_column :appointments, :starts_at, :datetime unless column_exists?(:appointments, :starts_at)
    add_column :appointments, :duration_minutes, :integer, default: 30, null: false unless column_exists?(:appointments, :duration_minutes)
    add_column :appointments, :status, :string, default: "pending", null: false unless column_exists?(:appointments, :status)
    add_column :appointments, :reschedule_token, :string unless column_exists?(:appointments, :reschedule_token)
    add_column :appointments, :reschedule_token_expires_at, :datetime unless column_exists?(:appointments, :reschedule_token_expires_at)

    # Old contact-form rows cannot become bookable appointments.
    execute "DELETE FROM appointments WHERE starts_at IS NULL"

    change_column_null :appointments, :starts_at, false
    change_column_null :appointments, :notes, true

    add_index :appointments, :starts_at unless index_exists?(:appointments, :starts_at)
    add_index :appointments, :status unless index_exists?(:appointments, :status)
    add_index :appointments, :reschedule_token, unique: true unless index_exists?(:appointments, :reschedule_token)

    unless table_exists?(:appointment_settings)
      create_table :appointment_settings do |t|
        t.string :timezone, null: false, default: "America/Denver"
        t.integer :slot_duration_minutes, null: false, default: 30
        t.integer :lead_time_hours, null: false, default: 24
        t.integer :bookable_days_ahead, null: false, default: 14
        t.json :weekly_hours, null: false
        t.timestamps
      end
    end
  end

  def down
    drop_table :appointment_settings, if_exists: true

    remove_index :appointments, :reschedule_token if index_exists?(:appointments, :reschedule_token)
    remove_index :appointments, :status if index_exists?(:appointments, :status)
    remove_index :appointments, :starts_at if index_exists?(:appointments, :starts_at)

    remove_column :appointments, :reschedule_token_expires_at if column_exists?(:appointments, :reschedule_token_expires_at)
    remove_column :appointments, :reschedule_token if column_exists?(:appointments, :reschedule_token)
    remove_column :appointments, :status if column_exists?(:appointments, :status)
    remove_column :appointments, :duration_minutes if column_exists?(:appointments, :duration_minutes)
    remove_column :appointments, :starts_at if column_exists?(:appointments, :starts_at)
    add_column :appointments, :budget, :string unless column_exists?(:appointments, :budget)

    if column_exists?(:appointments, :notes)
      rename_column :appointments, :notes, :message
      change_column_null :appointments, :message, false
    end

    if table_exists?(:appointments) && !table_exists?(:contact_entries)
      rename_table :appointments, :contact_entries
    end
  end
end
