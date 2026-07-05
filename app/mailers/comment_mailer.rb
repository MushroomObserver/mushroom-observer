# frozen_string_literal: true

# Notify user of comment on their object.
class CommentMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(sender:, receiver:, target:, comment:, email_type:)
    setup_user(receiver)
    title = :email_subject_comment.l(name: target.unique_text_name)
    debug_log(:comment, sender, receiver,
              object: "#{target.type_tag}-#{target.id}")
    mo_mail(title, to: receiver,
                   view_namespace: Views::Mailers::CommentMailer,
                   view_params: { subject: title, receiver:, sender:,
                                  target:, comment:, email_type: })
  end
end
