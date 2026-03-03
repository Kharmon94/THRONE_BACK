module Api
  module V1
    class ContactController < ApplicationController
      def create
        entry = ContactEntry.new(contact_params)
        if entry.save
          render json: { contact_entry: contact_entry_json(entry) }, status: :created
        else
          render json: { errors: entry.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def contact_params
        params.require(:contact_entry).permit(:name, :email, :company, :budget, :message)
      end

      def contact_entry_json(entry)
        {
          id: entry.id,
          name: entry.name,
          email: entry.email,
          company: entry.company,
          budget: entry.budget,
          message: entry.message,
          created_at: entry.created_at.iso8601
        }
      end
    end
  end
end
