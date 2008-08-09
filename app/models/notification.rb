class Notification < ActiveRecord::Base
  belongs_to :user

  # Returns: array of symbols used for the different flavors of Notifications
  def self.all_flavors()
    [:name, :observation, :user, :all_comments]
  end

  def calc_note(user, obs)
    if self.note_template
      self.note_template.gsub(':observer', user.login).gsub(':observation', "#{DOMAIN}/#{obs.id}")
    end
  end
end
