class CommentEmail < BaseEmail
  attr_accessor :comment

  def initialize(email)
    self.comment = Comment.find(email.get_integer(:comment))
    super(email)
  end

  def self.find_or_create_email(sender, receiver, comment)
    # Check for an already queued matching email
    email = QueuedEmail.find(:first, :include => [:queued_email_integers],
      :conditions => [
        'queued_emails.to_user_id = ?' +
        ' and queued_emails.flavor = "comment"' +
        ' and queued_email_integers.key = "comment"' +
        ' and queued_email_integers.value = ?', receiver.id, comment.id])
    if email
      # Only happens when queuing is enabled
      email.queued = Time.now()
      email.save()
    else
      email = QueuedEmail.new()
      email.setup(sender, receiver, :comment)
      email.add_integer(:comment, comment.id)
      email.finish()
    end
    email
  end

  def deliver_email
    if !comment
      raise "No comment found for email ##{email.id}"
    elsif user == to_user
      print "Skipping email with same sender and recipient: #{user.email}\n" if !TESTING
    else
      AccountMailer.deliver_comment(user, to_user, comment.object, comment)
    end
  end
end
