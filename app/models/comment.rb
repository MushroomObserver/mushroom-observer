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
#    none
#
#  Callbacks:
#    after_save    Automatically sends email to observation's owner.
#
################################################################################

class Comment < ActiveRecord::Base

  belongs_to :observation
  belongs_to :user

  def after_save
    observation = Observation.find(self.observation_id)
    sender      = User.find(self.user_id)

    # 'nathan' should get handled by a notification, but for now it's hardcoded
    recipients   = [User.find(observation.user_id), User.find_by_login('nathan')]
    for recipient in recipients
      if recipient && recipient.comment_email
        CommentEmail.find_or_create_email(sender, recipient, self)
      end
    end
  end

  protected
  validates_presence_of :summary, :user
end
