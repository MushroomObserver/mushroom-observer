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

  # Pure join tables — no destroy callbacks, no further cascades. Use
  # delete_all so destroying a project with thousands of obs doesn't
  # load and per-row-DELETE every join row.
  has_many :project_images, dependent: :delete_all
  has_many :images, through: :project_images

  has_many :project_observations, dependent: :delete_all
  has_many :observations, through: :project_observations
  has_many :locations, through: :observations

  has_many :project_excluded_observations, dependent: :delete_all
  has_many :excluded_observations, through: :project_excluded_observations,
                                   source: :observation

  has_many :project_species_lists, dependent: :delete_all
  has_many :species_lists, through: :project_species_lists

  has_many :project_target_names, dependent: :delete_all
  has_many :target_names, through: :project_target_names, source: :name

  has_many :project_target_locations, dependent: :delete_all
  has_many :target_locations, through: :project_target_locations,
                              source: :location

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
    ids = Lookup::Users.new(members).ids # User lookup only takes logins or ids
    joins(user_group: :user_group_users).
      merge(UserGroupUser.where(user: ids))
  }
  # Takes multiple name strings or ids, passes include_synonyms
  scope :names, lambda { |lookup:, **args|
    joins(:observations).merge(Observation.names(lookup:, **args))
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
  # Accepts multiple regions, see Observation.region for why this is singular
  scope :region, lambda { |place_names|
    where(location: Location.region(place_names))
  }

  scope :user_is_member, lambda { |user|
    user = User.safe_find(user)
    return all unless user

    where(user_group: user.user_groups)
  }

  scope :user_is_admin, lambda { |user|
    user_id = user.is_a?(Integer) ? user : user&.id

    joins(:admin_group_users).where(user: user_id)
  }

  scope :show_includes, lambda {
    strict_loading.includes(
      { comments: :user },
      :location
    )
  }
  scope :violations_includes, lambda {
    strict_loading.includes(
      { observations: [:location, :name, :user] },
      :target_names, :target_locations
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

  # Is +user+ a member of this Project? Reflects actual user_group
  # membership only — Site Admins (user.admin == true) get no implicit
  # membership; they self-promote via the Administer Project button.
  # See issue #4145.
  def member?(user)
    user && user_group.users.member?(user)
  end

  # Is +user+ an admin for this Project? Reflects actual admin_group
  # membership only — see #member? note about Site Admins.
  def is_admin?(user)
    user && admin_group.users.member?(user)
  end
  alias admin? is_admin?

  def trusted_by?(user)
    member = project_members.find_by(user: user)
    member&.trust_level != "no_trust"
  end

  def can_edit?(user)
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

  # Promote +user+ to Project Admin. Adds to user_group and admin_group,
  # and ensures a ProjectMember row exists — defaulting to
  # `trust_level: "editing"` on create, leaving any existing row's
  # trust_level alone. Matches the default produced by the add-member
  # flow. Idempotent. Used by the Site Admin self-promotion action
  # (issue #4145).
  def add_administrator(user)
    ProjectMember.find_or_create_by(project: self, user: user) do |pm|
      pm.trust_level = "editing"
    end
    user_group.users << user unless user_group.users.member?(user)
    admin_group.users << user unless admin_group.users.member?(user)
    log_add_admin(user)
  end

  def can_leave?(user)
    user && user_group.users.member?(user) && user.id != user_id
  end

  def member_status(user)
    return :OWNER.t if user == self.user
    return :ADMIN.t if is_admin?(user)
    return :MEMBER.t if member?(user)

    nil
  end

  def user_can_add_observation?(obs, user)
    obs.user == user || member?(user)
  end

  # SQL-based count over the four violation kinds (#4136). Each branch
  # plucks ids of OFFENDING observations and merges them into a Set
  # for dedup; total cost is O(violations) rather than the
  # O(visible_observations) cost of the full Ruby iteration in
  # `#violations`. Called from the projects index
  # (Tabs::ProjectsHelper#violations_button), so any per-project
  # work multiplies by the number of projects rendered.
  def count_violations
    return 0 unless constraints?

    ids = Set.new
    collect_date_violation_ids(ids)
    collect_bbox_violation_ids(ids)
    collect_target_name_violation_ids(ids)
    collect_target_location_violation_ids(ids)
    ids.size
  end

  def constraints?
    start_date || end_date || location ||
      target_names.any? || target_locations.any?
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
  # If the observation was excluded, remove it from the excluded list.
  # Saves it.
  def add_observation(obs)
    unexclude_observation(obs)
    return if observations.include?(obs)

    imgs = obs.images.select { |img| img.user_id == obs.user_id }
    observations.push(obs)
    imgs.each { |img| images.push(img) }
    touch
  end

  # Bulk variant of add_observation. Given a list of observation ids,
  # inserts all needed project_observations / project_images rows in
  # set-based SQL rather than emitting ~8 queries per observation.
  # Idempotent: pre-existing project_observations are left alone, and
  # any project_excluded_observations rows for these ids are dropped
  # (matching add_observation's un-exclude side effect).
  def bulk_add_observations(obs_ids)
    obs_ids = Array(obs_ids).map(&:to_i).uniq
    return 0 if obs_ids.empty?

    project_excluded_observations.where(observation_id: obs_ids).delete_all
    new_obs_ids = obs_ids - project_observations.where(observation_id: obs_ids).
                  pluck(:observation_id)
    return 0 if new_obs_ids.empty?

    insert_project_observations(new_obs_ids)
    insert_project_images_for(new_obs_ids)
    touch
    new_obs_ids.size
  end

  def insert_project_observations(obs_ids)
    rows = obs_ids.map { |obs_id| { project_id: id, observation_id: obs_id } }
    ProjectObservation.insert_all(rows)
  end

  # Pull image_ids whose owner matches the observation owner (matching
  # add_observation's per-row filter), excluding any (project_id, image_id)
  # rows already in project_images so we don't insert duplicates. (There
  # is no unique index on project_images, so this dedup is the only
  # protection — see #4181.)
  def insert_project_images_for(obs_ids)
    image_ids = ObservationImage.
                joins("INNER JOIN images ON images.id = " \
                      "observation_images.image_id").
                joins("INNER JOIN observations ON observations.id = " \
                      "observation_images.observation_id").
                where(observation_id: obs_ids).
                where("images.user_id = observations.user_id").
                distinct.pluck(:image_id)
    return if image_ids.empty?

    image_ids -= project_images.where(image_id: image_ids).pluck(:image_id)
    return if image_ids.empty?

    rows = image_ids.map { |img_id| { project_id: id, image_id: img_id } }
    ProjectImage.insert_all(rows)
  end
  private :insert_project_observations, :insert_project_images_for

  # Remove observation (and its images) from this project. Saves it.
  def remove_observation(obs)
    return unless observations.include?(obs)

    imgs_to_delete(obs).each { |img| images.delete(img) }
    observations.delete(obs)
    touch
  end

  # Exclude observation from this project's Updates tab candidate list.
  # If currently in the project, remove it first.
  def exclude_observation(obs)
    remove_observation(obs)
    return if excluded_observations.include?(obs)

    excluded_observations.push(obs)
    touch
  end

  # Un-exclude observation. Does not add it back to the project.
  def unexclude_observation(obs)
    return unless excluded_observations.include?(obs)

    excluded_observations.delete(obs)
    touch
  end

  # Remove observations that were matching this project via `name` as a
  # target (directly, via synonyms, or via sub-taxa of either), but
  # leave any observation whose name is still covered by some other
  # remaining target. Called after the project_target_name record has
  # already been destroyed, so `target_name_ids` reflects the
  # post-removal state.
  def purge_observations_matching_name(name)
    matching_name_ids = expanded_target_name_ids([name.id])
    if target_name_ids.any?
      matching_name_ids -= expanded_target_name_ids(target_name_ids)
    end
    return if matching_name_ids.empty?

    # Don't pluck into Ruby — a broad genus target could produce tens
    # of thousands of ids. Use a subquery relation for both deletions.
    matching_obs = Observation.where(name_id: matching_name_ids)
    observations.where(id: matching_obs).
      find_each { |obs| remove_observation(obs) }
    project_excluded_observations.
      where(observation_id: matching_obs).delete_all
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

  # Add target name to this project if not already present.
  def add_target_name(name)
    project_target_names.find_or_create_by!(name: name)
    touch
  rescue ActiveRecord::RecordNotUnique
    # Already exists, no-op
  end

  # Remove target name from this project. Also removes observations
  # matching this name (including synonyms) from both the project's
  # observations and its excluded_observations lists.
  def remove_target_name(name)
    record = project_target_names.find_by(name: name)
    return unless record

    record.destroy
    purge_observations_matching_name(name)
    touch
  end

  # Add target location to this project if not already present.
  def add_target_location(location)
    project_target_locations.find_or_create_by!(location: location)
    touch
  rescue ActiveRecord::RecordNotUnique
    # Already exists, no-op
  end

  # Remove target location from this project.
  def remove_target_location(location)
    record = project_target_locations.find_by(location: location)
    return unless record

    record.destroy
    touch
  end

  # Does this project have any target names or target locations?
  def has_targets?
    project_target_names.any? || project_target_locations.any?
  end

  # Observations matching target names (with synonyms / sub-taxa)
  # AND within target locations, then further constrained by the
  # project's date range and (when set) bounding box. When only one
  # kind of target is set, matches on that alone. The date and bbox
  # filters mirror the violations-page rule so an obs is a candidate
  # iff it would NOT be a violation if added.
  def candidate_observations
    name_ids = candidate_name_ids
    loc_ids = candidate_location_ids
    return Observation.none if name_ids.nil? && loc_ids.nil?

    scope = if name_ids && loc_ids
              Observation.where(id: name_ids).
                where(id: loc_ids)
            elsif name_ids
              Observation.where(id: name_ids)
            else
              Observation.where(id: loc_ids)
            end
    scope = constrain_to_project_date_range(scope)
    scope = constrain_to_project_bbox(scope)
    scope.order(created_at: :desc)
  end

  # GPS-inside-bbox OR (no GPS AND obs.location bbox is fully
  # contained in project bbox). Mirrors out_of_area_observations'
  # inverse so candidate_observations and the bbox violation kind
  # agree on what "in" means.
  def constrain_to_project_bbox(scope)
    return scope if location.nil?

    box_kwargs = location.bounding_box
    m_box = Mappable::Box.new(**box_kwargs)
    return scope unless m_box.valid?

    gps_in_ids = Observation.gps_in_box(m_box).select(:id)
    no_gps_in_ids = Observation.where(lat: nil).joins(:location).
                    merge(Location.in_box(**box_kwargs)).select(:id)
    scope.where(id: gps_in_ids).or(scope.where(id: no_gps_in_ids))
  end

  def constrain_to_project_date_range(scope)
    return scope if start_date.nil? && end_date.nil?
    return scope.where(Observation[:when].lteq(end_date)) if start_date.nil?
    return scope.where(Observation[:when].gteq(start_date)) if end_date.nil?

    scope.where(Observation[:when].between(start_date..end_date))
  end

  private

  # Same expansion rule as candidate_name_ids: each given name plus
  # its synonyms plus sub-taxa of both.
  def expanded_target_name_ids(name_ids)
    return [] if name_ids.empty?

    Lookup::Names.new(name_ids,
                      include_synonyms: true,
                      include_subtaxa: true).ids
  end

  def candidate_name_ids
    return unless target_names.any?

    Observation.names(lookup: target_name_ids,
                      include_synonyms: true,
                      include_subtaxa: true).select(:id)
  end

  def candidate_location_ids
    return unless target_locations.any?

    scope = Observation.joins(:location).
            where(location_suffix_conditions)
    scope = scope.merge(Observation.in_box(**location.bounding_box)) if location
    scope.select("observations.id")
  end

  # OR clause: location.name LIKE '%, <target>' OR = '<target>'
  def location_suffix_conditions
    tbl = Location.arel_table
    target_locations.map do |tl|
      escaped = self.class.sanitize_sql_like(tl.name)
      tbl[:name].matches("%, #{escaped}").
        or(tbl[:name].eq(tl.name))
    end.reduce(:or)
  end

  # Same shape as `location_suffix_conditions` but against
  # `observations.where` (used when an obs has no location_id).
  def where_suffix_conditions
    tbl = Observation.arel_table
    target_locations.map do |tl|
      escaped = self.class.sanitize_sql_like(tl.name)
      tbl[:where].matches("%, #{escaped}").
        or(tbl[:where].eq(tl.name))
    end.reduce(:or)
  end

  # ----- helpers for SQL-based count_violations (#4136) -----

  def collect_date_violation_ids(ids)
    return unless start_date || end_date

    ids.merge(out_of_range_observations.ids)
  end

  def collect_bbox_violation_ids(ids)
    return unless location

    ids.merge(obs_geoloc_outside_project_location.ids)
    ids.merge(obs_without_geoloc_location_not_contained_in_location.ids)
  end

  def collect_target_name_violation_ids(ids)
    return unless target_names.any?

    ids.merge(
      visible_observations.
        where.not(name_id: expanded_target_name_id_set.to_a).ids
    )
  end

  def collect_target_location_violation_ids(ids)
    return unless target_locations.any?

    passing = passing_target_location_ids
    ids.merge(visible_observations.where.not(id: passing).ids)
  end

  def passing_target_location_ids
    with_loc = visible_observations.joins(:location).
               where(location_suffix_conditions).
               pluck("observations.id")
    without_loc = visible_observations.where(location_id: nil).
                  where(where_suffix_conditions).pluck(:id)
    (with_loc + without_loc).uniq
  end

  public

  delegate :count, to: :candidate_observations, prefix: true

  # Candidate observations not already in the project and not excluded.
  # Used for the default Updates tab list and its badge count.
  def new_candidate_observations
    candidate_observations.
      where.not(id: observations.select(:id)).
      where.not(id: excluded_observations.select(:id))
  end

  delegate :count, to: :new_candidate_observations,
                   prefix: true, allow_nil: false

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
    obs_locs = Location.joins(:observations).
               merge(visible_observations).select(:id)
    Location.where(id: obs_locs).
      or(Location.where(id: target_location_ids)).
      distinct.count
  end

  def count_collections(name)
    observations.where(name:).count
  end

  VIOLATION_KINDS = [:date, :bbox, :target_name, :target_location].freeze

  # One entry per offending observation, with the set of violation
  # kinds that apply. Sorted alphabetically by obs.name.sort_name so
  # repeated runs render in a stable order. (Each violation Struct is
  # `[obs, kinds]`, where `kinds` is a subset of VIOLATION_KINDS.)
  Violation = Struct.new(:obs, :kinds)

  def violations
    return [] unless constraints?

    rows = visible_observations.includes(:name, :location).
           filter_map do |obs|
      kinds = violation_kinds_for(obs)
      next if kinds.empty?

      Violation.new(obs, kinds)
    end
    rows.sort_by { |v| v.obs.name&.sort_name.to_s.downcase }
  end

  # Returns the kinds of violation that apply to the given observation
  # (subset of VIOLATION_KINDS). Empty if the observation passes all
  # configured constraints.
  def violation_kinds_for(observation)
    kinds = []
    kinds << :date if violates_date_range?(observation)
    kinds << :bbox if violates_location?(observation)
    kinds << :target_name if violates_target_name?(observation)
    kinds << :target_location if violates_target_location?(observation)
    kinds
  end

  ##############################################################################
  #
  #  :section: queries re related Observations
  #
  ##############################################################################

  # Observations excluding non-primary members of multi-obs occurrences.
  def visible_observations
    observations.exclude_non_primary
  end

  def out_of_range_observations
    if start_date.nil? && end_date.nil?
      # performant query that returns empty ActiveRecord_Relation
      # (gps_hidden column has null: false)
      visible_observations.where(gps_hidden: nil)
    elsif start_date.nil?
      visible_observations.where(Observation[:when] > end_date)
    elsif end_date.nil?
      visible_observations.where(Observation[:when] < start_date)
    else
      visible_observations.where(Observation[:when] > end_date).
        or(visible_observations.where(Observation[:when] < start_date))
    end
  end

  def in_range_observations
    if start_date.nil? && end_date.nil?
      visible_observations
    elsif start_date.nil?
      visible_observations.where(Observation[:when] <= end_date)
    elsif end_date.nil?
      visible_observations.where(Observation[:when] >= start_date)
    else
      visible_observations.where(Observation[:when] <= end_date).
        and(visible_observations.where(Observation[:when] >= start_date))
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
    violation_kinds_for(observation).any?
  end

  def violates_location?(observation)
    return false if location.blank?

    !location.found_here?(observation)
  end

  # Ruby 3.4 (and 3.0+) handles beginless/endless ranges in
  # `Range#cover?` correctly — `(start..nil).cover?(date)`,
  # `(nil..end).cover?(date)`, and `(...).cover?(nil)` all return
  # the right boolean without raising. Verified locally; see Copilot
  # review on PR #4182.
  def violates_date_range?(observation)
    return false if start_date.nil? && end_date.nil?

    !(start_date..end_date).cover?(observation.when)
  end

  # Target-name violation: project has a non-empty target_names list
  # AND the observation's name (with synonyms and sub-taxa expansion,
  # matching candidate_observations) is not in it.
  def violates_target_name?(observation)
    return false unless target_names.any?

    expanded_target_name_id_set.exclude?(observation.name_id)
  end

  # Target-location violation: project has a non-empty target_locations
  # list AND no target's name is a comma-suffix (or exact) match of
  # the obs's location name (or `where`, when there's no location).
  # GPS overlap with a target_location does NOT satisfy the rule.
  def violates_target_location?(observation)
    return false unless target_locations.any?

    !target_location_suffix_match?(observation)
  end

  def target_location_suffix_match?(observation)
    name = if observation.location_id
             observation.location&.name
           else
             observation.where
           end
    return false if name.blank?

    target_locations.any? do |tl|
      name == tl.name || name.end_with?(", #{tl.name}")
    end
  end

  # Memoized: project's target_names with synonyms + sub-taxa expanded
  # into a Set of name_ids, matching the candidate_observations rule.
  # Used by violates_target_name? as a per-obs membership test.
  def expanded_target_name_id_set
    @expanded_target_name_id_set ||=
      expanded_target_name_ids(target_name_ids).to_set
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
    visible_observations.
      where.not(observations: { lat: nil }).not_in_box(**location.bounding_box)
  end

  def obs_without_geoloc_location_not_contained_in_location
    visible_observations.where(lat: nil).joins(:location).
      merge(
        # invert_where is safe (doesn't invert observations.where(lat: nil))
        Location.not_in_box(**location.bounding_box)
      )
  end
end
