class CreateContactEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :contact_entries, if_not_exists: true do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :company
      t.string :budget
      t.text :message, null: false

      t.timestamps
    end

    add_index :contact_entries, :created_at, if_not_exists: true
  end
end
