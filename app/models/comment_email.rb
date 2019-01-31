# Notify user of comment on their object.
class CommentEmail < AccountMailer
  def build(sender, receiver, target, comment)
    setup_user(receiver)
    @title = :email_subject_comment.l(name: target.unique_text_name)
    @sender = sender
    @target = target
    @comment = comment
    debug_log(:comment, sender, receiver,
              object: "#{target.type_tag}-#{target.id}")
    reply_to = receiver == target.user ? sender : nil
    mo_mail(@title, to: receiver, reply_to: reply_to)
  end
end
