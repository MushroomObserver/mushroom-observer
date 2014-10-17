# Ask reviewers for authorship credit.
class AuthorEmail < AccountMailer
  def build(sender, receiver, object, subject, message)
    setup_user(receiver)
    @title = subject
    @sender = sender
    @message = message || ""
    @object = object
    debug_log(:author_request, sender, receiver,
              object: "#{object.type_tag}-#{object.id}")
    mo_mail(@title, to: receiver, reply_to: sender)
  end
end
