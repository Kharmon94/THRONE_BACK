# frozen_string_literal: true

# Serves a built SPA from public/ when present. With the split Railway
# frontend deploy, public/index.html is usually absent — return 404 JSON
# instead of a RoutingError.
class SpaController < ActionController::Base
  def index
    path = Rails.public_path.join("index.html")
    unless path.exist?
      render json: { error: "Not Found" }, status: :not_found
      return
    end

    send_file path, disposition: "inline", type: "text/html"
  end
end
