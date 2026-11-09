# frozen_string_literal: true

module Api
  module V1
    # Phase 1 newsletter: double opt-in signup, confirmation and unsubscribe.
    # Signup/confirm are hard-gated by Newsletter::Config (off by default);
    # unsubscribe always works so nobody can be stuck subscribed.
    class NewsletterController < ApplicationController
      CHECK_EMAIL = { status: "check_email" }.freeze
      NOT_AVAILABLE = { error: "Email updates aren't open yet." }.freeze

      before_action :require_signup_enabled, only: %i[create confirm]

      # GET /api/v1/newsletter/config: public, no secrets or subscriber data.
      def public_config
        if Newsletter::Config.signup_enabled?
          render json: { signup_open: true, privacy_url: Newsletter::Config.privacy_url,
                         consent_version: Newsletter::Config.consent_version }
        else
          render json: { signup_open: false }
        end
      end

      # POST /api/v1/newsletter/subscriptions
      def create
        return render(json: CHECK_EMAIL, status: :accepted) if params[:website].present? # honeypot

        email = params[:email].to_s.strip.downcase
        errors = []
        errors << "Enter a valid email address." unless email.length <= 254 && email.match?(URI::MailTo::EMAIL_REGEXP)
        errors << "Please confirm you want to receive emails." unless ActiveModel::Type::Boolean.new.cast(params[:consent])
        return render(json: { errors: errors }, status: :unprocessable_entity) if errors.any?

        Newsletter::Subscribe.new(email: email, source: params[:utm_source], campaign: params[:utm_campaign]).call
        render json: CHECK_EMAIL, status: :accepted
      end

      # POST /api/v1/newsletter/confirmations { token }
      def confirm
        sub = NewsletterSubscriber.find_by_confirm_token(params[:token])
        return render(json: { status: "invalid_or_expired" }, status: :gone) unless sub

        sub.confirm!
        render json: { status: "subscribed" }
      end

      # POST /api/v1/newsletter/unsubscribe { token }
      def unsubscribe
        sub = NewsletterSubscriber.find_by_unsubscribe_token(params[:token])
        return render(json: { status: "invalid" }, status: :not_found) unless sub

        sub.unsubscribe!(method: "page")
        render json: { status: "unsubscribed" }
      end

      # POST /api/v1/newsletter/unsubscribe/one_click?token=...  (RFC 8058)
      # Mail providers POST "List-Unsubscribe=One-Click"; no login, no body, always 200.
      def one_click
        NewsletterSubscriber.find_by_unsubscribe_token(params[:token])&.unsubscribe!(method: "one_click")
        head :ok
      end

      private

      def require_signup_enabled
        render json: NOT_AVAILABLE, status: :not_found unless Newsletter::Config.signup_enabled?
      end
    end
  end
end
