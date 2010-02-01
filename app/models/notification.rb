#
#  = Notification Model
#
#  == Attributes
#
#  id::             Locally unique numerical id, starting at 1.
#  sync_id::        Globally unique alphanumeric id, used to sync with remote servers.
#  modified::       Date/time it was last modified.
#  user::           User that created it.
#  flavor::         Type of Notification.
#  obj_id::         Id of principle object.
#  note_template::  Template for an email (context depends on type of Notification).
#
#  == Class methods
#
#  all_flavors::    List of Notifcation types available.
#
#  == Instance methods
#
#  calc_note::      Create body of the email we're about to send.
#  object::         Return principle object involved.
#  summary::        String summarizing what this Notification is about.
#  link_params::    Hash of link_to options for edit action.
#  text_name::      Alias for +summary+ for debugging.
#
#  == Callbacks
#
#  None.
#
################################################################################

class Notification < AbstractModel
  belongs_to :user

  # List of all available flavors (Symbol's).
  def self.all_flavors
    [:name]
  end

  # Create body of the email we're about to send.  Each flavor requires a
  # different set of arguments:
  #
  # [name]
  #   user::      Owner of Observation.
  #   naming::    Naming that triggered this email.
  #
  def calc_note(args)
    if template = self.note_template
      case self.flavor
      when :name
        user   = args[:user]
        naming = args[:naming]
        raise "Missing 'user' argument for #{self.flavor} notification."   if !user
        raise "Missing 'naming' argument for #{self.flavor} notification." if !naming
        template.gsub(':observer', user.login).
                 gsub(':observation', "#{HTTP_DOMAIN}/#{naming.observation_id}").
                 gsub(':mailing_address', user.mailing_address).
                 gsub(':location', naming.observation.place_name).
                 gsub(':name', naming.format_name)
      end
    end
  end

  # Return principle object involved.  Again, this is different for each
  # flavor:
  #
  # name::   Name that User is tracking.
  #
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

  # Return a string summarizing what this Notification is about.
  def summary
    result = "Unrecognized notification flavor"
    case self.flavor
    when :name
      result = "#{:app_tracking.l} #{:name.l}: #{self.object ? self.object.display_name : '?'}"
    end
    result
  end
  alias_method :text_name, :summary

  # Returns hash of options to pass into link_to to link to edit action:
  #
  #   link_to("edit", notification.link_params)
  #
  def link_params
    result = {}
    case self.flavor
    when :name
      result[:controller] = :name
      result[:action] = :email_tracking
      result[:id] = self.obj_id
    end
    result
  end

################################################################################

protected

  def validate # :nodoc:
    if !self.user && !User.current
      errors.add(:user, :validate_notification_user_missing.t)
    end
  end
end
