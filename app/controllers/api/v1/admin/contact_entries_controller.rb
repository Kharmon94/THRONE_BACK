module Api
  module V1
    module Admin
      class ContactEntriesController < BaseController
        def index
          authorize! :read, ContactEntry
          entries = ContactEntry.order(created_at: :desc)
          render json: { contact_entries: entries.map { |e| contact_entry_json(e) } }
        end

        def destroy
          entry = ContactEntry.find(params[:id])
          authorize! :destroy, entry
          entry.destroy
          head :no_content
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Not found" }, status: :not_found
        end

        private

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
end
