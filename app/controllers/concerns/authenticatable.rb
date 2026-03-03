module Authenticatable
  extend ActiveSupport::Concern

  private

  def authenticate_user!
    render json: { error: "Unauthorized" }, status: :unauthorized unless current_user
  end

  def current_user
    return @current_user if defined?(@current_user)

    token = request.headers["Authorization"]&.split(" ")&.last
    return @current_user = nil unless token

    payload = JwtService.decode(token)
    return @current_user = nil unless payload && payload[:user_id]

    @current_user = User.find_by(id: payload[:user_id])
  end
end
