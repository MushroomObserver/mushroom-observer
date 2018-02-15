#
#  = Copyright Change Model
#
#  This model keeps track of change in copyright info in Image objects.
#
#  NOTE: each entry records the state *before* the time given.  If no
#  entries are present, then the copyright has never changed.
#
#  == Attributes
#
#  id::                 Locally unique numerical id, starting at 1.
#  user::               User who made the change.
#  updated_at::         Time the change was made.
#  target::             Object whose copyright info changed.
#  year::               *OLD* year.    \
#  name::               *OLD* name.     ) ©year name, license
#  license::            *OLD* license. /
#
#  == Callbacks
#
#  None.
#
################################################################################

class CopyrightChange < AbstractModel
  belongs_to :user
  belongs_to :target, polymorphic: true
  belongs_to :license

  ################################################################################

  protected

  validate :check_requirements
  def check_requirements # :nodoc:
    errors.add(:user, "missing user") unless user
    errors.add(:user, "missing target") unless target
    errors.add(:user, "missing modification time") unless updated_at
    errors.add(:user, "missing license") unless license
  end
end
