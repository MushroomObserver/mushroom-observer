# frozen_string_literal: true

#
#  = Notification Model
#
#  == Attributes
#
#  id::               Locally unique numerical id, starting at 1
#  updated_at::       Date/time it was last updated
#  user::             User who created it
#  flavor::           Type of Notification
#  obj_id::           Id of principal object
#  note_template::   Template for an email, context depends on Notification type
#  require_specimen:: Require observation to have a specimen?
#
#  == Class methods
#
#  all_flavors::       List of Notifcation types available.
#
#  == Instance methods
#
#  calc_note::         Create body of the email we're about to send.
#  target::            Return principle object involved.
#  summary::           String summarizing what this Notification is about
#  link_params::       Hash of link_to options for edit action
#  text_name::         Alias for +summary+ for debugging
#
#  == Callbacks
#
#  None.
#
class Notification < AbstractModel
  belongs_to :user

  # Do not change the integer associated with a value
  enum flavor:
       {
         name: 1,
         observation: 2,
         user: 3,
         all_comments: 4
       },
       _suffix: :flavor

  # List of all available flavors (strings).
  def self.all_flavors
    ["name"]
  end

  # Create body of the email we're about to send.  Each flavor requires a
  # different set of arguments:
  #
  # [name]
  #   user::      Owner of Observation.
  #   naming::    Naming that triggered this email.
  #
  def calc_note(args)
    return nil unless (template = note_template) && flavor == "name"

    tracker  = user
    observer = args[:user]
    naming   = args[:naming]
    raise("Missing 'user' argument for #{flavor} notification.") unless observer
    raise("Missing 'naming' argument for #{flavor} notification.") unless naming

    template.
      gsub(":observer", observer.login).
      gsub(":observation", "#{MO.http_domain}/#{naming.observation_id}").
      gsub(":mailing_address", tracker.mailing_address || "").
      gsub(":location", naming.observation.place_name).
      gsub(":name", naming.format_name)
  end

  # Return principal target involved.  Again, this is different for each
  # flavor:
  #
  # name::   Name that User is tracking.
  #
  def target
    @target ||= flavor == "name" ? Name.find(obj_id) : nil
  end

  # Return a string summarizing what this Notification is about.
  def summary
    if flavor == "name"
      "#{:TRACKING.l} #{:name.l}: #{target ? target.display_name : "?"}"
    else
      "Unrecognized notification flavor"
    end
  end
  alias text_name summary

  # Returns hash of options to pass into link_to to link to edit action:
  #
  #   link_to("edit", notification.link_params)
  #
  def link_params
    result = {}
    if flavor == "name"
      result[:controller] = :name
      result[:action] = :email_tracking
      result[:id] = obj_id
    end
    result
  end

  ##############################################################################

  protected

  validate :check_requirements
  def check_requirements # :nodoc:
    return unless !user && !User.current

    errors.add(:user, :validate_notification_user_missing.t)
  end
end
