class CreateDeviseTables < ActiveRecord::Migration[8.0]
  def change
    create_table :users, if_not_exists: true do |t|
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.timestamps null: false
      t.boolean :admin, default: false
      t.boolean :suspended, default: false
    end

    add_index :users, :email,                unique: true, if_not_exists: true
    add_index :users, :reset_password_token, unique: true, if_not_exists: true
  end
end
