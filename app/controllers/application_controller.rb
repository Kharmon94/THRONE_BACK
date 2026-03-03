class ApplicationController < ActionController::API
  include Authenticatable

  def current_ability
    @current_ability ||= Ability.new(current_user)
  end

  rescue_from CanCan::AccessDenied do |e|
    render json: { error: "Access denied", message: e.message }, status: :forbidden
  end
end
