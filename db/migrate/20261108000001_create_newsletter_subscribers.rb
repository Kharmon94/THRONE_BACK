# frozen_string_literal: true

# Newsletter phase 1: consent-based double opt-in storage. Reversible (drop table).
# Tokens are stored only as SHA-256 digests. No contacts are imported.
class CreateNewsletterSubscribers < ActiveRecord::Migration[8.0]
  def change
    create_table :newsletter_subscribers do |t|
      t.string :email, null: false
      t.string :status, null: false, default: "pending" # pending | subscribed | unsubscribed
      t.string :confirm_token_digest
      t.datetime :confirm_token_expires_at
      t.string :source   # allowlisted acquisition source or nil
      t.string :campaign # validated slug or nil
      t.string :consent_version   # version of the consent text shown at the latest request
      t.datetime :requested_at
      t.datetime :consented_at    # set when the double opt-in is confirmed
      t.datetime :confirmed_at
      t.datetime :unsubscribed_at
      t.string :unsubscribe_method # page | one_click
      t.integer :confirmation_sent_count, null: false, default: 0
      t.datetime :last_confirmation_sent_at
      t.string :last_confirmation_status # accepted_by_provider | failed | suppressed_by_flag | cooldown
      t.timestamps
    end
    add_index :newsletter_subscribers, :email, unique: true
    add_index :newsletter_subscribers, :confirm_token_digest, unique: true
    add_index :newsletter_subscribers, :status
  end
end
