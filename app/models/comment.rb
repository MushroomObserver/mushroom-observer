# Copyright (c) 2006 Nathan Wilson
# Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php

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
