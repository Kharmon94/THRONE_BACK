# frozen_string_literal: true

require "test_helper"

class ContactRequestTest < ActionDispatch::IntegrationTest
  test "creates a contact entry" do
    assert_difference("ContactEntry.count", 1) do
      post "/api/v1/contact",
           params: {
             contact_entry: {
               name: "Ada",
               email: "ada@example.com",
               message: "Hello from the site"
             }
           },
           as: :json
    end

    assert_response :created
  end

  test "rejects invalid contact entry" do
    post "/api/v1/contact",
         params: { contact_entry: { name: "", email: "bad", message: "" } },
         as: :json

    assert_response :unprocessable_entity
  end
end
