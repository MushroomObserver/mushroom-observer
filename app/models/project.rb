# encoding: utf-8
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
#  == Methods
#
#  is_member?::     Is a given User a member of this Project?
#  is_admin?::      Is a given User an admin for this Project?
#  text_name::      Alias for +title+ for debugging.
#
#  ==== Logging
#  log_create::        Log creation.
#  log_update::        Log update.
#  log_destroy::       Log destruction.
#  log_add_member::    Log addition of new member.
#  log_remove_member:: Log removal of member.
#  log_add_admin::     Log addition of new admin.
#  log_remove_admin::  Log removal of admin.
#
#  ==== Callbacks
#  orphan_drafts::     Orphan draft descriptions whe destroyed.
#
################################################################################

class Project < AbstractModel
  belongs_to :admin_group, :class_name => "UserGroup", :foreign_key => "admin_group_id"
  belongs_to :rss_log
  belongs_to :user
  belongs_to :user_group

  has_many :comments,  :as => :target, :dependent => :destroy
  has_many :interests, :as => :target, :dependent => :destroy

  before_destroy :orphan_drafts

  # Various debugging things require all models respond to +text_name+.  Just
  # returns +title+.
  def text_name
    title.to_s
  end

  # Same as +text_name+ but with id tacked on to make unique.
  def unique_text_name
    text_name + " (#{id})"
  end

  # Need these to be compatible with Comment.
  alias format_name text_name
  alias unique_format_name unique_text_name

  # Is +user+ a member of this Project?
  def is_member?(user)
    user and (self.user_group.users.member?(user) or user.admin)
  end

  # Is +user+ an admin for this Project?
  def is_admin?(user)
    user and (self.admin_group.users.member?(user) or user.admin)
  end

  ##############################################################################
  #
  #  :section: Logging
  #
  ##############################################################################

  def log_create; dolog(:log_project_created, true); end
  def log_update; dolog(:log_project_updated, true); end
  def log_destroy; dolog(:log_project_destroyed, true); end
  def log_add_member(user); dolog(:log_project_added_member, true, user); end
  def log_remove_member(user); dolog(:log_project_removed_member, false, user); end
  def log_add_admin(user); dolog(:log_project_added_admin, false, user); end
  def log_remove_admin(user); dolog(:log_project_removed_admin, false, user); end

  def dolog(tag, touch, user=nil)
    args = {}
    args[:name]  = user.login if user
    args[:touch] = touch
    if tag == :log_project_destroyed
      orphan_log(tag, args)
    else
      log(tag, args)
    end
  end

  ##############################################################################
  #
  #  :section: Callbacks
  #
  ##############################################################################

  # When deleting a project, "orphan" its unpublished drafts and remove the
  # user groups.
  def orphan_drafts
    title       = self.title
    user_group  = self.user_group
    admin_group = self.admin_group
    for d in NameDescription.find_all_by_source_type_and_project_id(:project, self.id)
      d.source_type = :source
      d.admin_groups.delete(admin_group)
      d.writer_groups.delete(admin_group)
      d.reader_groups.delete(user_group)
      d.save
    end
    user_group.destroy
    admin_group.destroy
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
    elsif self.title.binary_length > 100
      errors.add(:title, :validate_project_title_too_long.t)
    end
  end
end
