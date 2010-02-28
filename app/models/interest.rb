#
#  = Interest Model
#
#  Simple model for registering interest in arbitrary objects.  Any User may
#  register either positive interest ("watch") or negative interest ("ignore")
#  in any object.
#
#  In practice this means that the User receives some sort of notification
#  whenever anything changes or happens to objects that they are watching; and
#  that they stop receiving any sort of notifications about objects they are
#  ignoring (even if they own it, for example).
#
#  Currently this functionality is implemented for Observation, Name, and
#  Location.
#
#  == Attributes
#
#  id::             Locally unique numerical id, starting at 1.
#  sync_id::        Globally unique alphanumeric id, used to sync with remote servers.
#  modified::       Date/time it was last modified.
#  user::           User that created it.
#  object::         Object in question.
#  state::          Either true (watching) or false (ignoring).
#
#  == Class methods
#
#  find_all_by_object::   Find all Interests for a given object.
#
#  == Instance methods
#
#  summary::        Human-readable summary of state.
#  text_name::      Alias for +summary+ for debugging.
#
#  == Callbacks
#
#  None.
#
#  == Polymorphism
#
#  See comments under Comment.
#
################################################################################

class Interest < AbstractModel
  belongs_to :object, :polymorphic => true
  belongs_to :user

  # Find all Interests associated with a given object.  This should really be
  # created magically like all the other find_all_by_xxx methods, but the
  # polymorphism messes it up.
  def self.find_all_by_object(obj)
    if obj.is_a?(ActiveRecord::Base) && obj.id
      find_all_by_object_type_and_object_id(obj.class.to_s, obj.id)
    end
  end

  # To be compatible with Notification need to have summary string:
  #
  #   "Watching Observation: Amanita virosa"
  #   "Ignoring Location: Albion, California, USA"
  #
  def summary
    (self.state ? :WATCHING.l : :IGNORING.l) + ' ' +
    self.object_type.underscore.to_sym.l + ': ' +
    (self.object ? self.object.unique_format_name : '--')
  end
  alias_method :text_name, :summary

################################################################################

protected

  def validate # :nodoc:
    if !self.user && !User.current
      errors.add(:user, :validate_interest_user_missing.t)
    end

    if self.object_type.to_s.length > 30
      errors.add(:object_type, :validate_interest_object_type_too_long.t)
    end
  end
end
