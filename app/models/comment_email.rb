# Class for holding code specific to QueuedEmails intended to send email_naming emails.
#
# The separation is nice, but it kind of violates some of Rails assumptions.  In particular,
# the initialize if dangerous since it does saves.  However, I can't figure out a way to
# get these out of the database so as long the creation is explicit in code things should
# be fine.
class CommentEmail < QueuedEmail
  def self.find_or_create_email(sender, receiver, comment)
    # Check for an already queued matching email
    qed_email = CommentEmail.find(:first, :include => [:queued_email_integers],
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
      qed_email = CommentEmail.new()
      qed_email.setup(sender, receiver, :comment)
      qed_email.comment = comment
      qed_email.finish()
    end
    qed_email
  end
  
  # While this looks like it could be an instance method, it has to be a class
  # method for QueuedEmails that come out of the database to work.  See queued_emails.rb
  # for more details.
  def deliver_email
    if !comment
      print "No comment found for email ##{self.id}.\n"
    elsif user == to_user
      print "Skipping email with same sender and recipient: #{user.email}\n" if !TESTING
    else
      AccountMailer.deliver_comment(user, to_user, comment.object, comment)
    end
  end

  # ----------------------------
  #  Accessors
  # ----------------------------

  def comment=(comment)
    @comment = comment
    self.add_integer(:comment, comment.id);
  end

  def comment
    begin
      @comment ||= Comment.find(self.get_integer(:comment))
    rescue
    end
    @comment
  end
end
