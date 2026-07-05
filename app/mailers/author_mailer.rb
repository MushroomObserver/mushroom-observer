# frozen_string_literal: true

# Ask reviewers for authorship credit.
class AuthorMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(sender:, receiver:, object:, subject:, message:)
    setup_user(receiver)
    debug_log(:author_request, sender, receiver,
              object: "#{object.type_tag}-#{object.id}")
    mo_mail(subject, to: receiver, reply_to: sender,
                     view_params: { subject:, sender:, object:,
                                    message: message || "" })
  end
end
