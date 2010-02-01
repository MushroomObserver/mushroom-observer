#
#  = Comment Model
#
#  A comment is a bit of text a User attaches to an object such as an
#  Observation.  It is polymorphic in the sense that Comment's can be attached
#  to any kind of object, although currently only to Observation's.
#
#  == Attributes
#
#  id::        Locally unique numerical id, starting at 1.
#  sync_id::   Globally unique alphanumeric id, used to sync with remote servers.
#  created::   Date/time it was first created.
#  modified::  Date/time it was last modified.
#  user::      User that created it.
#  object::    Object it is attached to.
#  summary::   Summary line (100 chars).
#  comment::   Full text (any length).
#
#  == Instance Methods
#
#  text_name::              Alias for +summary+ for debugging.
#  object_type_localized::  Translate the name of the object type it's attached to.
#
#  == Callbacks
#
#  notify_users::           Sends notification emails after save.
#  log_destruction::        Log destruction after destroy.
#
#  == Polymorphism
#
#  ActiveRecord accomplishes polymorphism by storing the object _type_ along
#  side the usual object _id_.  So, while there are the convenience wrappers
#  +object+ and +object=+ that hide this detail, underneath there are actually
#  two columns in the database table:
#
#  object_type::  Class name of object (string).
#  object_id::    Id of object (integer).
#
#  Note that most of ActiveRecord's magic continues to work:
#
#    # Find first comment attached to an observation.
#    Comment.find_by_object(observation)
#
#    # Have we changed the object reference (either type or id)?
#    comment.object_changed?
#
################################################################################

class Comment < AbstractModel
  belongs_to :object, :polymorphic => true
  belongs_to :user

  after_save    :notify_users
  after_destroy :log_destruction

  # Callback that logs destruction after comment is destroyed.
  def log_destruction
    if (user = User.current) &&
       (object = self.object) &&
       (object.respond_to?(:log))
      object.log(:log_comment_destroyed, :summary => summary, :touch => false)
    end
  end

  # Callback called after creation or update.  Lots of people potentially can
  # receive an email whenever a Comment is posted:
  #
  # 1. the owner of the object
  # 2. users who already commented on the same object
  # 3. users who have expressed Interest in that object
  # 4. users masochistic enough to want to be notified of _all_ comments
  #
  def notify_users
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
        if recipient.created_here
          QueuedEmail::Comment.find_or_create_email(sender, recipient, self)
        end
      end
    end
  end

  # Returns +summary+ for debugging.
  def text_name
    summary.to_s
  end

  # Returns the name of the object type, translated into the local language.
  # Returns '' if fails for any reason.  Equivalent to:
  #
  #   comment.object_type.downcase.to_sym.l
  #
  def object_type_localized
    begin
      self.object_type.downcase.to_sym.l
    rescue
      ''
    end
  end

################################################################################

protected

  def validate # :nodoc:
    if !self.user && !User.current
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
