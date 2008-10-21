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
#    Comment.find_object(type, id)    Look up object referred to by type/id.
#
#  Callbacks:
#    after_save    Automatically sends email to observation's owner.
#
################################################################################

class Comment < ActiveRecord::Base

  belongs_to :object, :polymorphic => true
  belongs_to :user

  def after_save
    if self.object_type == 'Observation'
      observation = self.object
      sender      = self.user

      # 'nathan' should get handled by a notification, but for now it's hardcoded
      recipients  = [User.find(observation.user_id), User.find_by_login('nathan')]
      for recipient in recipients
        if recipient && recipient.comment_email
          CommentEmail.find_or_create_email(sender, recipient, self)
        end
      end
    end
  end

  # Look up an object given type and id.
  def self.find_object(type, id)
    begin
      type.classify.constantize.find_by_id(id.to_i)
    rescue NameError
      raise(ArgumentError, "Invalid object type, \"#{type}\".")
    end
  end

  # Same as 'comment.object_type.downcase.to_sym.l' (returns '' if fails for whatever reason).
  def object_type_localized
    if self.object_type 
      self.object_type.downcase.to_sym.l
    else
      ''
    end
  end

  protected
  validates_presence_of :summary, :user
end
