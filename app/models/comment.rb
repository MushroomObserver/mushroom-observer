#
#  Simple model for comments.  Each comment:
#
#  1. has a summary
#  2. has a body
#  3. belongs to a User (who made the comment)
#  4. belongs to an object (what comment is about)
#
#  Right now comments can only belong to Observation's, but they will
#  eventually belong to arbitrary objects via a polymorphic association.
#
#  Public Methods:
#    Comment.find_object(type, id)       Look up object referred to by type/id.
#    Comment.find_all_by_object(object)  Look up comments on an object.
#    destroy_with_log(user)              Destroy and log it in object's log.
#
#  Callbacks:
#    after_save    Automatically sends email to observation's owner.
#
################################################################################

class Comment < ActiveRecord::Base

  belongs_to :object, :polymorphic => true
  belongs_to :user

  # Posting a comment can trigger all sorts of emails.
  def after_save
    if self.object && self.object_type == 'Observation'
      object = self.object
      owner  = object.user
      sender = self.user
      recipients = []

      # Send to owner if they want.
      recipients.push(owner) if owner && owner.email_comments_owner

      # Send to masochists who want to see all comments.
      for user in User.find_all_by_email_comments_all(true)
        recipients.push(user)
      end

      # Send to other people who have commented on this same object if they want.
      for other_comment in Comment.find(:all, :conditions =>
          ['comments.object_type = ? AND comments.object_id = ? AND users.email_comments_response = TRUE',
          object.class.to_s, object.id], :include => 'user')
        recipients.push(other_comment.user)
      end

      # Send to people who have registered interest.
      # Also remove everyone who has explicitly said they are NOT interested.
      for interest in Interest.find_all_by_object(object)
        if interest.state
          recipients.push(interest.user)
        else
          recipients.delete(interest.user)
        end
      end

      # Send comment to everyone (except the person who wrote the comment!)
      for recipient in recipients.uniq - [sender]
        CommentEmail.find_or_create_email(sender, recipient, self)
      end
    end
  end

  # Look up an object given type and id.
  def self.find_object(type, id)
    begin
      type.classify.constantize.find_by_id(id.to_i)
    rescue NameError
      nil
      # raise(ArgumentError, "Invalid object type, \"#{type}\".")
    end
  end

  # Look up all comments for a given object.
  def self.find_all_by_object(object)
    # (Usually need to query something from the associated users, too, so include users here.)
    self.find(:all, :conditions => ['object_type = ? and object_id = ?', object.class.to_s, object.id],
      :include => 'user')
  end

  # Same as 'comment.object_type.downcase.to_sym.l' (returns '' if fails for whatever reason).
  def object_type_localized
    if self.object_type
      self.object_type.downcase.to_sym.l
    else
      ''
    end
  end

  # Destroy comment and log its destruction in the log for the object.
  def destroy_with_log(user)
    result = false
    summary = comment.summary
    object = comment.object
    if self.destroy
      object.log(:log_comment_destroyed, { :user => user.login,
        :summary => summary }, false) \
        if object && object.respond_to?(:log)
      result = true
    end
    return result
  end

  protected

  def validate # :nodoc:
    if !self.user
      errors.add(:user, :validate_comment_user_missing.t)
    end

    if self.summary.to_s.blank?
      errors.add(:summary, :validate_comment_summary_missing.t)
    elsif self.summary.length > 100
      errors.add(:summary, :validate_comment_summary_too_long.t)
    end

    if self.object_type.to_s.length > 30
      errors.add(:object_type, :validate_comment_object_type_too_long.t)
    end
  end
end
