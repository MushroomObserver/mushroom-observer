# Comment Email
class QueuedEmail::CommentAdd < QueuedEmail
  def comment
    get_object(:comment, Comment)
  end

  def self.find_or_create_email(sender, receiver, comment)
    # Check for an already queued matching email
    #    email = QueuedEmail.find(:first, :include => :queued_email_integers, # Rails 3
    #      :conditions => [
    #        'queued_emails.to_user_id = ?
    #          AND queued_emails.flavor = "QueuedEmail::CommentAdd"
    #          AND queued_email_integers.key = "comment"
    #          AND queued_email_integers.value = ?', receiver.id, comment.id])
    email = QueuedEmail.
            includes(:queued_email_integers).
            where("queued_emails.flavor" => "QueuedEmail::CommentAdd",
                  "queued_email_integers.key" => "comment",
                  "queued_emails.to_user_id" => comment.id,
                  "queued_email_integers.value" => receiver.id).
            first

    if email
      # Only happens when queuing is enabled, just touch 'queued' time.
      email.queued = Time.now
      email.save
    else
      email = create(sender, receiver)
      raise "Missing comment!" unless comment

      email.add_integer(:comment, comment.id)
      email.finish
    end
    email
  end

  def deliver_email
    # Make sure it hasn't been deleted since email was queued.
    if comment
      CommentEmail.build(user, to_user, comment.target, comment).deliver_now
    end
  end
end
