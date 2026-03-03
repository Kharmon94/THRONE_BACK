# This migration comes from active_storage (originally 20170806125915)
class CreateActiveStorageTables < ActiveRecord::Migration[8.0]
  def change
    create_table :active_storage_blobs, if_not_exists: true do |t|
      t.string   :key,          null: false
      t.string   :filename,     null: false
      t.string   :content_type
      t.text     :metadata
      t.string   :service_name, null: false
      t.bigint   :byte_size,    null: false
      t.string   :checksum

      if connection.supports_datetime_with_precision?
        t.datetime :created_at, precision: nil, null: false
      else
        t.datetime :created_at, null: false
      end
    end

    add_index :active_storage_blobs, :key, unique: true, if_not_exists: true

    create_table :active_storage_attachments, if_not_exists: true do |t|
      t.string     :name,     null: false
      t.references :record,   null: false, polymorphic: true, index: false
      t.references :blob,     null: false

      if connection.supports_datetime_with_precision?
        t.datetime :created_at, precision: nil, null: false
      else
        t.datetime :created_at, null: false
      end
    end

    add_index :active_storage_attachments, [:record_type, :record_id, :name, :blob_id],
      name: :index_active_storage_attachments_uniqueness, unique: true, if_not_exists: true
  end
end
