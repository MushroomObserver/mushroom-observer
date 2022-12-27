# frozen_string_literal: true

#
#  = Name Tracker Model
#
#  == Attributes
#
#  id::               Locally unique numerical id, starting at 1
#  updated_at::       Date/time it was last updated
#  user::             User who created it
#  name_id::          Id of name we're tracking.
#  note_template::    Template for an email
#  require_specimen:: Require observation to have a specimen?
#
#  == Instance methods
#
#  calc_note::         Create body of the email we're about to send.
#  name::              Return the name we're tracking.
#  summary::           String summarizing what this Name Tracker is about
#  link_params::       Hash of link_to options for edit action
#  text_name::         Alias for +summary+ for debugging
#
#  == Callbacks
#
#  None.
#
class NameTracker < AbstractModel
  belongs_to :user
  belongs_to :name

  scope :for_user,
        ->(user) { where(user: user) }

  # Used as an "opt-in" check-box in the UI form.
  attr_accessor :note_template_enabled

  # Create body of the email we're about to send.
  #
  # [name]
  #   user::      Owner of Observation.
  #   naming::    Naming that triggered this email.
  #
  def calc_note(args)
    return nil unless (template = note_template)

    tracker  = user
    observer = args[:user]
    naming   = args[:naming]
    raise("Missing 'user' argument for name tracker.") unless observer
    raise("Missing 'naming' argument for name tracker.") unless naming

    template.
      gsub(":observer", observer.login).
      gsub(":observation", "#{MO.http_domain}/#{naming.observation_id}").
      gsub(":mailing_address", tracker.mailing_address || "").
      gsub(":location", naming.observation.place_name).
      gsub(":name", naming.format_name)
  end

  # Return a string summarizing what this NameTracker is about.
  def summary
    "#{:TRACKING.l} #{:name.l}: #{name ? name.display_name : "?"}"
  end
  alias text_name summary
  alias unique_text_name summary

  # Returns hash of options to pass into link_to to link to edit action:
  #
  #   link_to("edit", name_tracker.link_params)
  #
  def link_params
    result = {}
    result[:controller] = :name
    result[:action] = :email_tracking
    result[:id] = name_id
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
