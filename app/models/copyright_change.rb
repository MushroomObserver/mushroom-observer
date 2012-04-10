# encoding: utf-8
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
#  modified::           Time the change was made.
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
  belongs_to :target, :polymorphic => true
  belongs_to :license

################################################################################

protected

  def validate # :nodoc:
    if !self.user
      errors.add(:user, 'missing user')
    end
    if !self.target
      errors.add(:user, 'missing target')
    end
    if !self.modified
      errors.add(:user, 'missing modification time')
    end
    if !self.license
      errors.add(:user, 'missing license')
    end
  end 
end
