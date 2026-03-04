# frozen_string_literal: true

class SpaController < ActionController::Base
  def index
    path = Rails.public_path.join("index.html")
    raise ActionController::RoutingError, "Not Found" unless path.exist?

    send_file path, disposition: "inline", type: "text/html"
  end
end
