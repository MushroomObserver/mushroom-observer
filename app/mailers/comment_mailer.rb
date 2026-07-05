# frozen_string_literal: true

# Notify user of comment on their object.
class CommentMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(sender:, receiver:, target:, comment:)
    setup_user(receiver)
    title = :email_subject_comment.l(name: target.unique_text_name)
    debug_log(:comment, sender, receiver,
              object: "#{target.type_tag}-#{target.id}")
    mo_mail(title, to: receiver,
                   view_namespace: Views::Mailers::CommentMailer,
                   view_params: { subject: title, receiver:, sender:,
                                  target:, comment:,
                                  email_type: comment_email_type(receiver,
                                                                 comment) })
  end

  private

  # "owner" / "response" / "all" — computed here (not in the view;
  # views shouldn't query the database) because telling "response"
  # from "all" needs an extra Comment query beyond the plain
  # receiver-is-the-owner? check.
  def comment_email_type(receiver, comment)
    return "owner" if receiver == comment.target.user

    earlier_comment = Comment.where(target_type: comment.target_type,
                                    target_id: comment.target_id,
                                    user_id: receiver.id).
                      any? { |c| c.created_at < comment.created_at }
    earlier_comment ? "response" : "all"
  end
end
