# frozen_string_literal: true

# User asking user about an image.
class CommercialInquiryMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  # Note the recipient comes from the Image object, image.user
  def build(sender:, image:, message:)
    setup_user(image.user)
    @sender = sender
    @title = :email_subject_commercial_inquiry.l(name: image.unique_text_name)
    @image = image
    @message = message || ""
    debug_log(:commercial_inquiry, sender, @user, image:)
    mo_mail(@title, to: @user, reply_to: sender)
  end
end
