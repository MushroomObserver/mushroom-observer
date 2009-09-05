#
#  Simple model for registering interest in arbitrary objects.  There are
#  absolutely no restrictions on what kind of objects may be referred to.
#
#  In practice "interest" in an object means that the user receives some sort
#  of notification whenever anything changes or happens to that object.
#
#  The only object this works for right now is Observation: users expressing
#  interest in an observation will be notified whenever someone comments on
#  it, proposes a new name, or the consensus name changes.
#
#  The basic properties of an "interest" object are:
#
#  1. refers to an object (via polymorphic relationship)
#  2. has an owner (user who is expressing interest or lack thereof)
#  3. has a state (true or false: interested or not)
#
#  Note that there are effectively three states: explicit interest, explicit
#  lack of interest, and no preference whatsoever.  The last state is what
#  is expressed by absence of an Interest instance linking a given user to a
#  given object.  In this case the user's global preferences and other standard
#  heuristics are consulted to determine whether that user is notified of
#  changes to that object.
#
#  Public Methods:
#    interest.user          User who is expressing interest.
#    interest.object        Object user is interested in.
#    interest.state         True = interested, false = not interested.
#    interest.summary       "Watching observation Amanita velosa"
#
#    Interest.find_all_by_object(object)   Look up all interest in an object.
#
################################################################################

class Interest < ActiveRecord::Base

  belongs_to :object, :polymorphic => true
  belongs_to :user

  # Look up all interest in a given object.
  def self.find_all_by_object(object)
    self.find(:all, :conditions => ['object_type = ? and object_id = ?', object.class.to_s, object.id], :include => 'user')
  end

  # To be compatible with Notification: returns string summarizing the object,
  # e.g., "Watching observation Amanita virosa".
  def summary
    (self.state ? :app_watching.l : :app_ignoring.l) + ' ' +
    self.object_type.underscore.to_sym.l + ' ' +
    (self.object ? self.object.unique_format_name.t : '--')
  end

  protected

  def validate # :nodoc:
    if !self.user
      errors.add(:user, :validate_interest_user_missing.t)
    end

    if self.object_type.to_s.length > 30
      errors.add(:object_type, :validate_interest_object_type_too_long.t)
    end
  end
end
