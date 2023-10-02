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
#  can_join?::      Can the current user join this Project?
#  can_leave?::     Can the current user leave this Project?
#  user_can_add_observation?:: Can user add observation to this Project
#  violates_constraints?:: Does a given obs violate the Project constraints
#  text_name::      Alias for +title+ for debugging.
#  Proj.can_edit?:: Check if User has permission to edit an Obs/Image/etc.
#  Proj.admin_power?:: Check for admin for a project of this Obs
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
  belongs_to :admin_group, class_name: "UserGroup"
  belongs_to :location
  belongs_to :rss_log
  belongs_to :user
  belongs_to :user_group

  has_many :admin_group_users, through: :admin_group, source: :users
  has_many :member_group_users, through: :user_group, source: :users

  has_many :comments,  as: :target, dependent: :destroy, inverse_of: :target
  has_many :interests, as: :target, dependent: :destroy, inverse_of: :target

  has_many :project_images, dependent: :destroy
  has_many :images, through: :project_images

  has_many :project_observations, dependent: :destroy
  has_many :observations, through: :project_observations

  has_many :project_species_lists, dependent: :destroy
  has_many :species_lists, through: :project_species_lists

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

  def can_join?(user)
    open_membership && !is_member?(user)
  end

  def can_leave?(user)
    is_member?(user) && user.id != user_id
  end

  def user_can_add_observation?(obs, user)
    accepting_observations && (obs.user == user ||
                               is_member?(user))
  end

  def violates_constraints?(obs)
    violates_location?(obs) # || violates_date?(obs)
  end

  def violates_location?(obs)
    return false if location.blank?

    !location.found_here?(obs)
  end

  def count_violations
    return 0 unless location

    count = observations.where.not(lat: nil).count
    count - observations.in_box(n: location.north, s: location.south,
                                e: location.east, w: location.west).count
  end

  def constraints
    "#{:LOCATION.t}: #{place_name}; #{:DATES.t}: #{date_range}"
  end

  # Check if user has permission to edit a given object.
  def self.can_edit?(obj, user)
    return false unless user
    return true  if obj.user_id == user.id
    return false if obj.projects.empty?

    group_ids = user.user_group_ids
    obj.projects.each do |project|
      next if project.open_membership
      return true if group_ids.member?(project.user_group_id) ||
                     group_ids.member?(project.admin_group_id)
    end
    false
  end

  # Check if this user is an admin for a project that includes
  # this observation.
  def self.admin_power?(observation, user)
    return false unless user
    return false if observation.projects.empty?

    group_ids = user.user_group_ids
    observation.projects.each do |project|
      return true if group_ids.member?(project.admin_group_id)
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
    touch
  end

  # Remove image this project. Saves it.
  def remove_image(img)
    return unless images.include?(img)

    images.delete(img)
    touch
  end

  # Add observation (and its images) to this project if not already done so.
  # Saves it.
  def add_observation(obs)
    return if observations.include?(obs) || !accepting_observations

    imgs = obs.images.select { |img| img.user_id == obs.user_id }
    observations.push(obs)
    imgs.each { |img| images.push(img) }
    touch
  end

  # Remove observation (and its images) from this project. Saves it.
  def remove_observation(obs)
    return unless observations.include?(obs)

    imgs_to_delete(obs).each { |img| images.delete(img) }
    observations.delete(obs)
    touch
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

  # NOTE: Arel is definitely more efficient than AR for this join.
  def arel_select_leave_these_img_ids(obs, imgs)
    img_ids = imgs.map(&:id)

    ObservationImage.arel_table.join(ProjectObservation.arel_table).on(
      ObservationImage[:image_id].in(img_ids).and(
        ObservationImage[:observation_id].not_eq(obs.id).and(
          ObservationImage[:observation_id].eq(
            ProjectObservation[:observation_id]
          )
        ).and(ProjectObservation[:project_id].eq(id))
      )
    ).project(ObservationImage[:image_id])
  end

  # Add species_list to this project if not already done so.  Saves it.
  def add_species_list(spl)
    return if species_lists.include?(spl)

    species_lists.push(spl)
    touch
  end

  # Remove species_list from this project. Saves it.
  def remove_species_list(spl)
    return unless species_lists.include?(spl)

    species_lists.delete(spl)
    touch
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

  def place_name
    if location
      location.display_name
    else
      ""
    end
  end

  def place_name=(place_name)
    place_name = place_name.strip_squeeze
    where = if User.current_location_format == "scientific"
              Location.reverse_name(place_name)
            else
              place_name
            end
    loc = Location.find_by_name(where)
    self.location = (loc)
  end

  ##############################################################################
  #
  #  :section: Dates
  #
  ##############################################################################

  def current?
    !future? && !past?
  end

  def dates_exclude?(date)
    !dates_include?(date)
  end

  def dates_include?(date)
    starts_no_later_than?(date) && ends_no_earlier_than?(date)
  end

  # convenience methods for date range display
  def date_range(format = "%Y-%m-%d")
    "#{start_date_str(format)} - #{end_date_str(format)}"
  end

  def start_date_str(format = "%Y-%m-%d")
    start_date.nil? ? :INDEFINITE.t : start_date.strftime(format)
  end

  def end_date_str(format = "%Y-%m-%d")
    end_date.nil? ? :INDEFINITE.t : end_date.strftime(format)
  end

  def duration_str
    if start_date && end_date
      (end_date - start_date + 1).to_i.to_s
    elsif start_date
      :show_project_duration_unlimited_no_end.t
    elsif end_date
      :show_project_duration_unlimited_no_start.t
    else
      :show_project_duration_unlimited.t
    end
  end

  ##############################################################################

  private

  def future?
    start_date&.future?
  end

  def past?
    end_date&.past?
  end

  def starts_no_later_than?(date)
    !start_date&.after?(date)
  end

  def ends_no_earlier_than?(date)
    !end_date&.before?(date)
  end
end
