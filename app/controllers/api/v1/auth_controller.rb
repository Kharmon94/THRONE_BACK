module Api
  module V1
    class AuthController < ApplicationController
      def sign_in
        user = User.find_for_database_authentication(email: params[:email] || params.dig(:user, :email))
        password = params[:password] || params.dig(:user, :password)
        if user&.valid_password?(password)
          if user.respond_to?(:suspended?) && user.suspended?
            render json: { error: "Account suspended" }, status: :unauthorized
            return
          end
          token = JwtService.encode({ user_id: user.id })
          render json: { token: token, user: user_json(user) }
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      def sign_up
        user = User.new(sign_up_params)
        user.admin = true if User.count.zero?
        if user.save
          token = JwtService.encode({ user_id: user.id })
          render json: { token: token, user: user_json(user) }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def me
        render json: { error: "Unauthorized" }, status: :unauthorized and return unless current_user
        render json: { user: user_json(current_user) }
      end

      private

      def sign_up_params
        params.require(:user).permit(:email, :password, :password_confirmation)
      end

      def user_json(user)
        {
          id: user.id,
          email: user.email,
          admin: user.admin?
        }
      end
    end
  end
end
