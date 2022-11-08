# frozen_string_literal: true

# User asking user about an image.
class CommercialMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(sender, image, commercial_inquiry)
    setup_user(image.user)
    @sender = sender
    @title = :email_subject_commercial_inquiry.l(name: image.unique_text_name)
    @image = image
    @message = commercial_inquiry || ""
    debug_log(:commercial_inquiry, sender, @user, image: image)
    mo_mail(@title, to: @user, reply_to: sender)
  end
end
