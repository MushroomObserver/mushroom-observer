# Copyright (c) 2006 Nathan Wilson
# Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php

class Comment < ActiveRecord::Base

  belongs_to :observation
  belongs_to :user

  def after_save
    observation = Observation.find(self.observation_id)
    sender      = User.find(self.user_id)
    recipient   = User.find(observation.user_id)
    begin
      if recipient.comment_email
        AccountMailer.deliver_comment(sender, observation, self)
      end
    rescue
      # Failing to send email should not throw an error
    end
  end

  protected
  validates_presence_of :summary, :user
end
