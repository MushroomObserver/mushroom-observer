class Notification < ActiveRecord::Base
  belongs_to :user

  # Returns: array of symbols used for the different flavors of Notifications
  def self.all_flavors()
    [:name, :observation, :user, :all_comments]
  end

  # Create body of the email notification we're about to send.
  def calc_note(args)
    if template = self.note_template
      case self.flavor
      when :name
        user   = args[:user]
        naming = args[:naming]
        raise "Missing 'user' argument for #{self.flavor} notification."   if !user
        raise "Missing 'naming' argument for #{self.flavor} notification." if !naming
        template.gsub(':observer', user.login).
                 gsub(':observation', "#{DOMAIN}/#{naming.observation_id}").
                 gsub(':mailing_address', user.mailing_address).
                 gsub(':location', naming.observation.place_name).
                 gsub(':name', naming.format_name)
      end
    end
  end

  # Return principle object involved, e.g., the Name if notifying observers
  # of taxa you're doing research on.
  def object
    result = nil
    if @object
      result = @object
    else
      case self.flavor
      when :name
        result = Name.find(self.obj_id)
      end
      @object = result
    end
    result
  end

  # Return a string summarizing what this notification is about.
  def summary()
    result = "Unrecognized notification flavor"
    case self.flavor
    when :name
      result = "#{:app_tracking.l} #{:name.l}: #{self.object ? self.object.display_name : '?'}"
    end
    result
  end

  # Returns hash of options for use in link_to() call to link to edit action:
  #   link_to("edit", notification.link_params)
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
