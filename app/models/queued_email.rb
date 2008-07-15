class QueuedEmail < ActiveRecord::Base
  has_many :queued_email_integers,      :dependent => :destroy
  has_many :queued_email_strings,       :dependent => :destroy
  has_one :queued_email_note,           :dependent => :destroy
  belongs_to :user
  belongs_to :to_user, :class_name => "User", :foreign_key => "to_user_id"
  
  # Returns: array of symbols, from :Form to :Kingdom, then :Group.
  def self.all_flavors()
    [:comment]
  end

  def self.save_comment(sender, receiver, comment)
    qed_email = QueuedEmail.find(:first, :include => [:queued_email_integers],
      :conditions => [
        'queued_emails.flavor = "comment"' +
        ' and queued_email_integers.key = "comment"' +
        ' and queued_email_integers.value = ?', comment.id])
    ints = QueuedEmailInteger.find_all_by_key_and_value(:comment, comment.id)
    if qed_email
      qed_email.queued = Time.now()
      qed_email.save()
    else
      qed_email = QueuedEmail.new()
      qed_email.user = sender
      qed_email.to_user = receiver
      qed_email.flavor = :comment
      qed_email.queued = Time.now()
      qed_email.save()
      qed_email.add_integer(:comment, comment.id)
    end
    qed_email
  end
  
  def add_integer(key, value)
    qed_int = QueuedEmailInteger.new()
    qed_int.queued_email = self
    qed_int.key = key
    qed_int.value = value
    qed_int.save()
    qed_int
  end
  
  def send_email
    result = false
    case self.flavor
    when :comment
      self.send_comment_email
      result = true
    else
      print "Unrecognized email flavor: #{self.flavor}\n"
    end
    result
  end
  
  def send_comment_email
    observation = nil
    comment = nil
    for qi in self.queued_email_integers
      case qi.key
      when "comment"
        comment = Comment.find(qi.value)
      else
        print "Unrecognized integer key: #{qi.key}\n"
      end
    end
    if comment
      observation = comment.observation
      begin
        if User.find(observation.user_id).comment_email
          print "Sending email\n"
          AccountMailer.deliver_comment(self.user, self.to_user, observation, comment)
          # On success remove from queue
        end
      rescue
        # Failing to send email should not throw an error
      end
    else
      print "No comment found\n"
      # Delete this queued item, but send person who queued a note that it failed
    end
  end
end
