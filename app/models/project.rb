#
#  = Project Model
#
#  A Project is used to encapsulate a collaboration effort to write species
#  descriptions.  Technically, a Project is just defined as a UserGroup of
#  members and a UserGroup of admins, which together own a collection of draft
#  Name Descriptions. 
#
#  == Attributes
#
#  id::             Locally unique numerical id, starting at 1.
#  sync_id::        Globally unique alphanumeric id, used to sync with remote servers.
#  created::        Date/time it was first created.
#  modified::       Date/time it was last modified.
#  user::           User that created it.
#  admin_group::    UserGroup of admins.
#  user_group::     UserGroup of members.
#  title::          Title string.
#  summary::        Summary of purpose.
#
#  == Class methods
#
#  None.
#
#  == Instance methods
#
#  draft_names::    List of Name Descriptions associated with this Project.
#  is_member?::     Is a given User a member of this Project?
#  is_admin?::      Is a given User an admin for this Project?
#  text_name::      Alias for +title+ for debugging.
#
#  == Callbacks
#
#  None.
#
################################################################################

class Project < ActiveRecord::MO
  belongs_to :user
  belongs_to :user_group
  belongs_to :admin_group, :class_name => "UserGroup", :foreign_key => "admin_group_id"
  has_many :draft_names

  # Is +user+ a member of this Project?
  def is_member?(user)
    user and (self.user_group.users.member?(user) or user.admin)
  end

  # Is +user+ an admin for this Project?
  def is_admin?(user)
    user and (self.admin_group.users.member?(user) or user.admin)
  end

  # Various debugging things require all models respond to +text_name+.  Just
  # returns +title+.
  def text_name
    title.to_s
  end

################################################################################

protected

  def validation # :nodoc:
    if !self.user && !User.current
      errors.add(:user, :validate_project_user_missing.t)
    end
    if !self.admin_group
      errors.add(:admin_group, :validate_project_admin_group_missing.t)
    end
    if !self.user_group
      errors.add(:user_group, :validate_project_user_group_missing.t)
    end

    if self.title.to_s.blank?
      errors.add(:title, :validate_project_title_missing.t)
    elsif self.title.length > 100
      errors.add(:title, :validate_project_title_too_long.t)
    end
  end
end
