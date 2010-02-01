#
#  = User Group Model
#
#  Model that describes a group of Users.  Pretty straight-forward.
#
#  == Attributes
#
#  id::         Locally unique numerical id, starting at 1.
#  sync_id::    Globally unique alphanumeric id, used to sync with remote servers.
#  created::    Date/time it was first created.
#  modified::   Date/time it was last modified.
#  name::       Name of the group, must be unique.
#
#  == Class methods
#
#  None.
#
#  == Instance methods
#
#  users::          List of Users in the group.
#  project::        Project, if one defines their membership using this group.
#  admin_project::  Project, if one defines their admins using this group.
#  text_name::      Alias for +name+ for debugging.
#
#  == Callbacks
#
#  None.
#
################################################################################

class UserGroup < AbstractModel
  has_and_belongs_to_many :users
  has_one :project
  has_one :admin_project, :class_name => "Project", :foreign_key => "admin_group_id"

  # Returns +name+ for debugging.
  def text_name
    name.to_s
  end
end
