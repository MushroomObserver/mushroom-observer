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
#  id::                Locally unique numerical id, starting at 1.
#  created_at::        Date/time it was first created.
#  updated_at::        Date/time it was last updated.
#  user::              User that created it.
#  admin_group::       UserGroup of admins.
#  user_group::        UserGroup of members.
#  title::             Title string.
#  summary::           Summary of purpose.
#  field_slip_prefix:: Prefix for associated field slip codes
#  open_membership  Enable users to add themselves, disable shared editing
#  location::
#  image::
#  start_date::     start date or nil
#  end_date::       end date or nil
#
#  == Methods
#
#  member?::     Is a given User a member of this Project?
#  is_admin?::      Is a given User an admin for this Project?
#  can_join?::      Can the current user join this Project?
#  can_leave?::     Can the current user leave this Project?
#  current?::       Project (based on dates) has started and hasn't ended
#  user_can_add_observation?:: Can user add observation to this Project
#  violates_constraints?:: Does a given obs violate the Project constraints
#  count_violations    # of project Observations which violate constraints
#  text_name::         Alias for +title+ for debugging.
#  Proj.can_edit?::    Check if User has permission to edit an Obs/Image/etc.
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
###############################################################################
class Project < AbstractModel # rubocop:disable Metrics/ClassLength
  include Date

  belongs_to :admin_group, class_name: "UserGroup"
  belongs_to :location
  belongs_to :image
  belongs_to :rss_log
  belongs_to :user
  belongs_to :user_group

  has_many :admin_group_users, through: :admin_group, source: :users
  has_many :member_group_users, through: :user_group, source: :users
  has_many :project_members, dependent: :destroy
  has_many :members, through: :project_members, source: :users

  has_many :comments, as: :target, dependent: :destroy, inverse_of: :target
  has_many :field_slips, dependent: :nullify
  has_many :interests, as: :target, dependent: :destroy, inverse_of: :target

  has_many :project_images, dependent: :destroy
  has_many :images, through: :project_images

  has_many :project_observations, dependent: :destroy
  has_many :observations, through: :project_observations
  has_many :locations, through: :observations

  has_many :project_species_lists, dependent: :destroy
  has_many :species_lists, through: :project_species_lists

  has_many :aliases, class_name: "ProjectAlias", dependent: :destroy

  before_destroy :orphan_drafts
  validates :field_slip_prefix, uniqueness: true, allow_blank: true
  validates :field_slip_prefix,
            allow_blank: true,
            format: { with: /\A[A-Z0-9][A-Z0-9-]*\z/,
                      message: proc { :alphanumerics_only.t } }

  scope :order_by_default,
        -> { order_by(::Query::Projects.default_order) }

  scope :members, lambda { |members|
    joins(user_group: :user_group_users).
      merge(UserGroupUser.where(user: members))
  }
  scope :title_has,
        ->(phrase) { search_columns(Project[:title], phrase) }
  scope :has_summary,
        ->(bool = true) { not_blank_condition(Project[:summary], bool:) }
  scope :summary_has,
        ->(phrase) { search_columns(Project[:summary], phrase) }
  scope :field_slip_prefix_has,
        ->(phrase) { search_columns(Project[:field_slip_prefix], phrase) }

  scope :has_images,
        ->(bool = true) { joined_relation_condition(:project_images, bool:) }
  scope :has_observations, lambda { |bool = true|
    joined_relation_condition(:project_observations, bool:)
  }
  scope :has_species_lists, lambda { |bool = true|
    joined_relation_condition(:project_species_lists, bool:)
  }

  scope :pattern, lambda { |phrase|
    cols = (Project[:title] + Project[:summary].coalesce("") +
            Project[:field_slip_prefix].coalesce(""))
    search_columns(cols, phrase).distinct
  }

  scope :show_includes, lambda {
    strict_loading.includes(
      { comments: :user },
      :location
    )
  }
  scope :violations_includes, lambda {
    strict_loading.includes(
      { observations: [:location, :user] }
    )
  }

  # Project handles all of its own logging.
  self.autolog_events = []

  # Various debugging things require all models respond to +text_name+.  Just
  # returns +title+.
  def text_name
    title.to_s
  end

  # Ensure that field_slip_prefix is uppercase and at most 255
  # characters.
  def field_slip_prefix=(val)
    self[:field_slip_prefix] = if val && val.strip != ""
                                 val.strip.upcase[0, 255]
                               end
  end

  # Same as +text_name+ but with id tacked on to make unique.
  def unique_text_name
    "#{text_name} (#{id || "?"})"
  end

  # Need these to be compatible with Comment.
  alias format_name text_name
  alias unique_format_name unique_text_name

  # Is +user+ a member of this Project?
  def member?(user)
    user && (user_group.users.member?(user) || user.admin)
  end

  # Is +user+ an admin for this Project?
  def is_admin?(user)
    user && (admin_group.users.member?(user) || user.admin)
  end
  alias admin? is_admin?

  def trusted_by?(user)
    member = project_members.find_by(user: user)
    member&.trust_level != "no_trust"
  end

  def can_edit?(user = User.current)
    admin?(user)
  end

  def can_edit_content?(user)
    member = project_members.find_by(user: user)
    member&.trust_level == "editing"
  end

  def can_join?(user)
    open_membership && !member?(user)
  end

  def join(user)
    return unless can_join?(user)

    ProjectMember.create!(project: self, user:,
                          trust_level: "hidden_gps")
    user_group.users << user unless user_group.users.member?(user)
  end

  def can_leave?(user)
    user && user_group.users.member?(user) && user.id != user_id
  end

  def member_status(user)
    return :OWNER.t if user == self.user

    is_admin?(user) ? :ADMIN.t : :MEMBER.t
  end

  def user_can_add_observation?(obs, user)
    obs.user == user || member?(user)
  end

  def count_violations
    return out_of_range_observations.count unless location

    out_of_range_observations.to_a.union(out_of_area_observations).size
  end

  def constraints
    "#{:DATES.t}: #{date_range}; #{:LOCATION.t}: #{place_name}"
  end

  def constraints?
    start_date || end_date || location
  end

  # Check if user has permission to edit a given object.
  def self.can_edit?(obj, user)
    return false unless user
    return true  if obj.user_id == user.id
    return false if obj.projects.empty?

    group_ids = user.user_group_ids
    obj.projects.each do |project|
      next unless project.can_edit_content?(obj.user)
      return true if group_ids.member?(project.admin_group_id)
    end
    false
  end

  # Check if this user is an admin for a project that includes
  # this observation.
  def self.admin_power?(observation, user)
    return false unless user
    return false if observation.projects.empty?

    observation.projects.each do |project|
      if project.is_admin?(user)
        member = project.project_members.find_by(user: observation.user)
        return member&.trust_level != "no_trust"
      end
    end
    false
  end

  def add_images(imgs)
    imgs.each { |x| add_image(x) }
  end

  def remove_images(imgs)
    imgs.each { |x| remove_image(x) }
  end

  def add_observations(obs)
    obs.each { |x| add_observation(x) }
  end

  def remove_observations(obs)
    obs.each { |x| remove_observation(x) }
  end

  def add_species_lists(lists)
    lists.each { |x| add_species_list(x) }
  end

  def remove_species_lists(lists)
    lists.each { |x| remove_species_list(x) }
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
    return if observations.include?(obs)

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
    args = { touch: touch }
    args[:name] = user.login if user
    tag == :log_project_destroyed ? orphan_log(tag, args) : log(tag, args)
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

  def where
    location ? location.name : ""
  end

  def place_name
    location ? location.display_name : ""
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

  def name_count
    Checklist::ForProject.new(self).num_taxa
  end

  def location_count
    locations.distinct.count
  end

  def count_collections(name)
    observations.where(name:).count
  end

  def violations
    out_of_range_observations.to_a.union(out_of_area_observations)
  end

  # Is at least one violation removable by the current user?
  def violations_removable_by_current_user?
    user_ids = violations.map(&:user_id)
    return false unless user_ids.any?

    admin_group_user_ids.union(user_ids).include?(User.current_id)
  end

  ##############################################################################
  #
  #  :section: queries re related Observations
  #
  ##############################################################################

  def out_of_range_observations
    if start_date.nil? && end_date.nil?
      # performant query that returns empty ActiveRecord_Relation
      # (gps_hidden column has null: false)
      observations.where(gps_hidden: nil)
    elsif start_date.nil?
      observations.where(Observation[:when] > end_date)
    elsif end_date.nil?
      observations.where(Observation[:when] < start_date)
    else
      observations.where(Observation[:when] > end_date).
        or(observations.where(Observation[:when] < start_date))
    end
  end

  def in_range_observations
    if start_date.nil? && end_date.nil?
      observations
    elsif start_date.nil?
      observations.where(Observation[:when] <= end_date)
    elsif end_date.nil?
      observations.where(Observation[:when] >= start_date)
    else
      observations.where(Observation[:when] <= end_date).
        and(observations.where(Observation[:when] >= start_date))
    end
  end

  # Obs lat/lon is outside Project.location exor
  # Obs location is not a subset of Project.location
  def out_of_area_observations
    return [] if location.nil?

    obs_geoloc_outside_project_location +
      obs_without_geoloc_location_not_contained_in_location
  end

  def violates_constraints?(observation)
    violates_location?(observation) ||
      violates_date_range?(observation)
  end

  def violates_location?(observation)
    return false if location.blank?

    !location.found_here?(observation)
  end

  def violates_date_range?(observation)
    !(start_date..end_date).cover?(observation.when)
  end

  def trackers
    FieldSlipJobTracker.where(prefix: field_slip_prefix)
  end

  def can_add_field_slip?(user)
    member?(user) || can_join?(user)
  end

  def alias_data(target)
    @target_alias_details ||= target_alias_details(target.class)
    @target_alias_details[target.id] || []
  end

  def check_for_alias(str, target_type)
    project_alias = aliases.find_by(name: str, target_type:)
    return str unless project_alias

    project_alias.target.format_name
  end

  private ###############################

  def target_alias_details(target_type)
    aliases.
      where(target_type:).
      order(:name).
      group_by(&:target_id).
      transform_values do |aliases|
        aliases.map { |project_alias| [project_alias.name, project_alias.id] }
      end
  end

  def obs_geoloc_outside_project_location
    observations.
      where.not(observations: { lat: nil }).not_in_box(**location.bounding_box)
  end

  def obs_without_geoloc_location_not_contained_in_location
    observations.where(lat: nil).joins(:location).
      merge(
        # invert_where is safe (doesn't invert observations.where(lat: nil))
        Location.not_in_box(**location.bounding_box)
      )
  end
end
