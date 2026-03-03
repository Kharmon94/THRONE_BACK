class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects, if_not_exists: true do |t|
      t.string :title, null: false
      t.text :description
      t.string :category
      t.boolean :featured, default: false
      t.string :live_url
      t.string :github_url
      t.string :status, default: "draft"
      t.string :color
      t.string :client
      t.string :year
      t.integer :position, default: 0
      t.text :tags
      t.references :user, foreign_key: true, null: true

      t.timestamps
    end

    add_index :projects, :status, if_not_exists: true
  end
end
