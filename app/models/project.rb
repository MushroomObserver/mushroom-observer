# frozen_string_literal: true

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
#  created_at::     Date/time it was first created.
#  updated_at::     Date/time it was last updated.
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
#  Proj.can_edit?:: Check if User has permission to edit an Obs/Image/etc.
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
#
class Project < AbstractModel
  belongs_to :admin_group, class_name: "UserGroup",
                           foreign_key: "admin_group_id"
  belongs_to :rss_log
  belongs_to :user
  belongs_to :user_group

  has_many :comments,  as: :target, dependent: :destroy
  has_many :interests, as: :target, dependent: :destroy

  has_and_belongs_to_many :images
  has_and_belongs_to_many :observations
  has_and_belongs_to_many :species_lists

  before_destroy :orphan_drafts

  # Project handles all of its own logging.
  self.autolog_events = []

  # Various debugging things require all models respond to +text_name+.  Just
  # returns +title+.
  def text_name
    title.to_s
  end

  # Same as +text_name+ but with id tacked on to make unique.
  def unique_text_name
    text_name + " (#{id || "?"})"
  end

  # Need these to be compatible with Comment.
  alias format_name text_name
  alias unique_format_name unique_text_name

  # Is +user+ a member of this Project?
  def is_member?(user)
    user && (user_group.users.member?(user) || user.admin)
  end

  # Is +user+ an admin for this Project?
  def is_admin?(user)
    user && (admin_group.users.member?(user) || user.admin)
  end

  # Check if user has permission to edit a given object.
  def self.can_edit?(obj, user)
    return false unless user
    return true  if obj.user_id == user.id
    return false if obj.projects.empty?

    group_ids = user.user_groups.map(&:id)
    obj.projects.each do |project|
      return true if group_ids.member?(project.user_group_id) ||
                     group_ids.member?(project.admin_group_id)
    end
    false
  end

  def add_images(imgs)
    imgs.each { |x| add_image(x) }
  end

  def remove_images(imgs)
    imgs.each { |x| remove_image(x) }
  end

  def add_observations(imgs)
    imgs.each { |x| add_observation(x) }
  end

  def remove_observations(imgs)
    imgs.each { |x| remove_observation(x) }
  end

  def add_species_lists(imgs)
    imgs.each { |x| add_species_list(x) }
  end

  def remove_species_lists(imgs)
    imgs.each { |x| remove_species_list(x) }
  end

  # Add image this project if not already done so.  Saves it.
  def add_image(img)
    images.push(img) unless images.include?(img)
  end

  # Remove image this project. Saves it.
  def remove_image(img)
    return unless images.include?(img)

    images.delete(img)
    update_attribute(:updated_at, Time.zone.now)
  end

  # Add observation (and its images) to this project if not already done so.
  # Saves it.
  def add_observation(obs)
    return if observations.include?(obs)

    imgs = obs.images.select { |img| img.user_id == obs.user_id }
    observations.push(obs)
    imgs.each { |img| images.push(img) }
  end

  # Remove observation (and its images) from this project. Saves it.
  def remove_observation(obs)
    return unless observations.include?(obs)

    imgs_to_delete(obs).each { |img| images.delete(img) }
    observations.delete(obs)
    update_attribute(:updated_at, Time.zone.now)
  end

  def imgs_to_delete(obs)
    imgs = obs.images.select { |img| img.user_id == obs.user_id }
    return imgs if imgs.none?

    # Do not delete images which are attached to other observations
    # still attached to this project.
    leave_these_img_ids = Image.connection.select_values(
      arel_select_leave_these_img_ids(obs, imgs).to_sql
    ).map(&:to_i)
    imgs.reject { |img| leave_these_img_ids.include?(img.id) }
  end

  # Note: Arel is definitely more efficient than AR for this join.
  # rubocop:disable Metrics/AbcSize
  def arel_select_leave_these_img_ids(obs, imgs)
    io = Arel::Table.new(:images_observations)
    op = Arel::Table.new(:observations_projects)
    img_ids = imgs.map(&:id)

    io.join(op).on(
      io[:image_id].in(img_ids).and(
        io[:observation_id].not_eq(obs.id).and(
          io[:observation_id].eq(op[:observation_id])
        ).and(op[:project_id].eq(id))
      )
    ).project(io[:image_id])
  end
  # rubocop:enable Metrics/AbcSize

  # Add species_list to this project if not already done so.  Saves it.
  def add_species_list(spl)
    species_lists.push(spl) unless species_lists.include?(spl)
  end

  # Remove species_list from this project. Saves it.
  def remove_species_list(spl)
    return unless species_lists.include?(spl)

    species_lists.delete(spl)
    update_attribute(:updated_at, Time.zone.now)
  end

  def self.find_by_title_with_wildcards(str)
    find_using_wildcards("title", str)
  end

  ##############################################################################
  #
  #  :section: Logging
  #
  ##############################################################################

  def log_create
    do_log(:log_project_created, true)
  end

  def log_update
    do_log(:log_project_updated, true)
  end

  def log_destroy
    do_log(:log_project_destroyed, true)
  end

  def log_add_member(user)
    do_log(:log_project_added_member, true, user)
  end

  def log_remove_member(user)
    do_log(:log_project_removed_member, false, user)
  end

  def log_add_admin(user)
    do_log(:log_project_added_admin, false, user)
  end

  def log_remove_admin(user)
    do_log(:log_project_removed_admin, false, user)
  end

  def do_log(tag, touch, user = nil)
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
    drafts = NameDescription.where(
      source_type: NameDescription.source_types[:project], project_id: id
    ) + LocationDescription.where(
      source_type: LocationDescription.source_types[:project], project_id: id
    )
    orphan_each_draft(drafts)
    user_group&.destroy
    admin_group&.destroy
  end

  def orphan_each_draft(drafts)
    drafts.each do |d|
      d.source_type = :source
      d.admin_groups.delete(admin_group)
      d.writer_groups.delete(admin_group)
      d.reader_groups.delete(user_group)
      d.save
    end
  end

  ##############################################################################

  protected

  def validation # :nodoc:
    if !user && !User.current
      errors.add(:user, :validate_project_user_missing.t)
    end
    unless admin_group
      errors.add(:admin_group, :validate_project_admin_group_missing.t)
    end
    unless user_group
      errors.add(:user_group, :validate_project_user_group_missing.t)
    end

    if title.to_s.blank?
      errors.add(:title, :validate_project_title_missing.t)
    elsif title.size > 100
      errors.add(:title, :validate_project_title_too_long.t)
    end
  end
end
