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
  
  def summary()
    result = "Unrecognized notification flavor"
    case self.flavor
    when :name
      name = Name.find(self.obj_id)
      result = "Tracking name: #{name.display_name}" if name
    end
    result
  end
  
  def link_params()
    result = {}
    case self.flavor
    when :name
      result[:controller] = :name
      result[:action] = :email_tracking
      result[:id] = self.obj_id
    end
    result
  end

  protected

  def validate # :nodoc:
    if !self.user
      errors.add(:user, :validate_notification_user_missing.t)
    end
  end
end
