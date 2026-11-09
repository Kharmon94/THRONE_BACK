# frozen_string_literal: true

class NewsletterMailer < ApplicationMailer
  # Transactional double-opt-in confirmation, sent only in response to the
  # person's own request and only when Newsletter::Config.delivery_enabled?.
  def confirm_subscription
    @subscriber = params[:subscriber]
    @confirm_url = "#{Newsletter::Config.frontend_origin}/newsletter#confirm=#{params[:token]}"
    @expires_hours = (NewsletterSubscriber::CONFIRM_TOKEN_TTL / 1.hour).to_i
    @privacy_url = Newsletter::Config.privacy_url

    headers = { to: @subscriber.email, subject: "Confirm your Throne Tech email subscription" }
    headers[:reply_to] = Newsletter::Config.reply_to if Newsletter::Config.reply_to.present?
    mail(**headers)
  end
end
