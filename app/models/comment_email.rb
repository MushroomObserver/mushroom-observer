# Class for holding code specific to QueuedEmails intended to send comment emails.
#
# The separation is nice, but it kind of violates some of Rails assumptions.
# The initialize is dangerous since it does saves.  However, I can't figure out
# a way to get these out of the database.  As long as the creation is explicit
# in code things should be fine. 
class CommentEmail < QueuedEmail
  def self.find_or_create_email(sender, receiver, comment)
    # Check for an already queued matching email
    qed_email = QueuedEmail.find(:first, :include => [:queued_email_integers],
      :conditions => [
        'queued_emails.to_user_id = ?' +
        ' and queued_emails.flavor = "comment"' +
        ' and queued_email_integers.key = "comment"' +
        ' and queued_email_integers.value = ?', receiver.id, comment.id])
    if qed_email
      # Only happens when queuing is enabled
      qed_email.queued = Time.now()
      qed_email.save()
    else
      if receiver.comment_email
        qed_email = CommentEmail.new()
        qed_email.setup(sender, receiver, :comment)
        qed_email.add_integer(:comment, comment.id)
        qed_email.finish()
      end
    end
    qed_email
  end
  
  # While this looks like it could be an instance method, it has to be a class
  # method for QueuedEmails that come out of the database to work.  See queued_emails.rb
  # for more details.
  def self.deliver_email(email)
    observation = nil
    comment = nil
    (comment_id,) = email.get_integers([:comment])
    comment = Comment.find(comment_id) if comment_id
    if comment
      observation = comment.observation
      if email.to_user.comment_email # Make sure it hasn't changed
        AccountMailer.deliver_comment(email.user, email.to_user, observation, comment)
      end
    else
      print "No comment found (#{self.id})\n"
    end
  end
end
