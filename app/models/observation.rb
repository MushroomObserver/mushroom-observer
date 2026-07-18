# frozen_string_literal: true

#  = Observation Model
#
#  An Observation is a mushroom seen at a certain Location and time, as
#  recorded by a User.  This is at the core of the site.  It can have any
#  number of Image's, Naming's, Comment's, Interest's.
#
#  == Voting
#
#  Voting is still in a state of flux.  At the moment User's create Naming's
#  and other User's Vote on them.  We combine the Vote's for each Naming, cache
#  the Vote for each Naming in the Naming.  However no Naming necessarily wins
#  -- instead Vote's are tallied for each Synonym (see calc_consensus for full
#  details).  Thus the accepted Name of the winning Synonym is cached in the
#  Observation along with its winning Vote score.
#
#  == Location
#
#  An Observation can belong to either a defined Location (+location+, a
#  Location instance) or an undefined one (+where+, just a String), and even
#  occasionally both (see below).  To make this a little easier, you can refer
#  to +place_name+ instead, which returns the name of whichever is present.
#
#  *NOTE*: We were clearly having trouble making up our mind whether or not to
#  set +where+ when +location+ was present.  The only safe heuristic is to use
#  +location+ if it's present, then fall back on +where+ -- +where+ may or may
#  not be set (or even accurate?) if +location+ is present.
#
#  *NOTE*: If a mushroom is seen at a mushroom fair or an herbarium, we don't
#  necessarily know where the mushroom actually grew.  In this case, we enter
#  the mushroom fair / herbarium as the +place_name+ and set the special flag
#  +is_collection_location+ to false.
#
#  == Attributes
#
#  id::                     Locally unique numerical id, starting at 1.
#  created_at::             Date/time it was first created.
#  updated_at::             Date/time it was last updated.
#  user_id::                User that created it.
#  when::                   Date it was seen.
#  where::                  Where it was seen (just a String).
#  location::               Where it was seen (Location).
#  lat::                    Exact latitude of location.
#  lng::                    Exact longitude of location.
#  alt::                    Exact altitude of location. (meters)
#  is_collection_location:: Is this where it was growing?
#  gps_hidden::             Hide exact lat/lng?
#  name::                   Consensus Name (never deprecated, never nil).
#  vote_cache::             Cache Vote score for the winning Name.
#  thumb_image::            Image to use as thumbnail (if any).
#  specimen::               Does User have a specimen available?
#  notes::                  Arbitrary text supplied by User and serialized.
#  num_views::              Number of times it has been viewed.
#  last_view::              Last time it was viewed.
#  log_updated_at::         Cache of RssLogs.updated_at, for speedier index
#  collector::              Display string for who collected the specimen.
#  collector_user_id::      FK to the User who collected it, when known.
#  inat_id::                iNaturalist id (deprecated; the import provenance
#                           now lives on an import ExternalLink, #4299)
#
#  ==== "Fake" attributes
#  place_name::             Wrapper on top of +where+ and +location+.
#                           Handles location_format.
#
#  == Class methods
#
#  recent_by_user::         Find last Observation by given User (+ eager-loads).
#  define_a_location::      Update any observations using the old "where" name.
#  touch_when_logging::     Override of AbstractModel's hook when updating log
#  ---
#  no_notes::               value of observation.notes if there are no notes
#  no_notes_persisted::     no_notes persisted in the db
#  other_notes_key::        key used for general Observation notes
#  other_notes_part::       other_notes_key as a String
#  notes_part_id::          id of textarea for a Notes heading
#  notes_area_id_prefix     prefix for id of textarea for a Notes heading
#  export_formatted::       notes (or any hash) to string with marked up
#                           captions (keys)
#  show_formatted::         notes (or any hash) to string with plain
#                           captions (keys)
#
#  ==== Scopes
#
#  created_at("yyyy-mm-dd", "yyyy-mm-dd")
#  updated_at("yyyy-mm-dd", "yyyy-mm-dd")
#  found_on("yyyymmdd")
#  found_after("yyyymmdd")
#  found_before("yyyymmdd")
#  found_between(start, end)
#  names(name)
#  names_like(string)
#  has_name
#  by_user(user)
#  has_location
#  locations(location)
#  region(where)
#  in_box(north:, south:, east:, west:) geoloc is in the box
#  not_in_box(north:, south:, east:, west:) geoloc is outside the box
#  is_collection_location
#  has_images
#  has_notes
#  has_notes_field(field)
#  notes_has(note)
#  has_specimen
#  has_sequences
#  confidence (min %, max %)
#  has_comments
#  comments_has(summary)
#  projects(project)
#  herbaria(herbaria)
#  species_lists(species_list)
#  project_lists(project)
#
#  == Instance methods
#
#  comments::               List of Comment's attached to this Observation.
#  images_sorted::          List of Images attached, sorted thumb_img first.
#  interests::              List of Interest's attached to this Observation.
#  sequences::              List of Sequences which belong to this Observation.
#  species_lists::          List of SpeciesList's that contain this Observation.
#  other_notes_key::        key used for general Observation notes
#  other_notes_part::       other_notes_key as a String
#  notes_part_id::          id of textarea for a Notes heading
#  notes_part_value::       value for textarea for a Notes heading
#  form_notes_parts::       note parts to display in create & edit form
#  notes_normalized_key::   key (of the notes parts array)
#  notes_export_formatted:: notes to string with marked up captions (keys)
#  notes_show_formatted::   notes to string with plain captions (keys)
#
#  ==== Name Formats #  text_name::              Plain text.
#  format_name::            Textilized. (uses name.observation_name)
#  unique_text_name::       Plain text, with id added to make unique.
#  unique_format_name::     Textilized, with id added to make unique.
#
#  ==== Namings and Votes
#  dump_votes::             Dump all the Naming and Vote info as known by this
#                           Observation and its associations.
#
#  ==== Images
#  images::                 List of Image's attached to this Observation.
#  add_image::              Attach an Image.
#  remove_image::           Remove an Image.
#
#  ==== Projects
#  can_edit?::              Check if user has permission to edit this obs.
#
#  ==== Callbacks
#  add_spl_callback::           After add: update contribution.
#  remove_spl_callback::        After remove: update contribution.
#  notify_species_lists::       Before destroy: log destruction on spls.
#  destroy_dependents::         After destroy: destroy Naming's.
#  notify_users_after_change::  After save: call notify_users (if important).
#  notify_users_before_destroy:: Before destroy: call notify_users.
#  notify_users::               After save/destroy/image: send email.
#  announce_consensus_change::  After consensus changes: send email.
#
class Observation < AbstractModel # rubocop:disable Metrics/ClassLength
  include HasPlaceName

  # Transient flag: when set, the before_create default that copies the
  # entering user into `collector` is skipped. Field-slip-originated
  # observations set this so a foray recorder is never auto-claimed as
  # the collector (the collector is written on the physical slip). See
  # build_observation and default_collector_to_creator.
  attr_accessor :skip_collector_default

  include Scopes

  belongs_to :thumb_image, class_name: "Image",
                           inverse_of: :thumb_glossary_terms
  belongs_to :name # (used to cache consensus name)
  belongs_to :location
  belongs_to :rss_log
  belongs_to :user
  # The MO user who collected the specimen, when that identity is known.
  # Distinct from `user` (who entered the record). Null for imports until
  # the identity is claimed (#4217) and for legacy native obs. See #4211.
  belongs_to :collector_user, class_name: "User", optional: true
  belongs_to :inat_import, optional: true

  # Has to go before "has many interests" or interests will be destroyed
  # before it has a chance to notify the interested users of the destruction.
  before_destroy :notify_users_before_destroy

  has_many :votes
  has_many :comments,  as: :target, dependent: :destroy, inverse_of: :target
  has_many :interests, as: :target, dependent: :destroy, inverse_of: :target
  has_many :sequences, dependent: :destroy
  has_many :external_links, as: :target, dependent: :destroy

  # DO NOT use :dependent => :destroy -- this causes it to recalc the
  # consensus several times and send bogus emails!!
  has_many :namings

  has_many :observation_images, dependent: :destroy
  has_many :images, through: :observation_images

  has_many :project_observations, dependent: :destroy
  has_many :projects, through: :project_observations

  has_many :species_list_observations, dependent: :destroy
  has_many :species_lists, through: :species_list_observations,
                           after_add: :add_spl_callback,
                           before_remove: :remove_spl_callback

  has_many :observation_collection_numbers, dependent: :destroy
  has_many :collection_numbers, through: :observation_collection_numbers
  belongs_to :occurrence, optional: true

  # Field slip reached through occurrence (no longer a direct FK)
  def field_slip
    occurrence&.field_slip
  end

  def field_slip_id
    occurrence&.field_slip_id
  end

  # Backward-compatible writer: creates/reuses an occurrence to
  # link this observation to the given field slip.
  def field_slip=(slip)
    if slip.nil?
      # Detach: handled by clearing occurrence
      return
    end

    old_occ = occurrence
    occ = slip.occurrence
    occ ||= Occurrence.create!(
      user: user || current_user,
      primary_observation: self,
      field_slip: slip
    )
    self.occurrence = occ
    cleanup_old_occurrence(old_occ, occ)
  end

  has_many :observation_herbarium_records, dependent: :destroy
  has_many :herbarium_records, through: :observation_herbarium_records

  has_many :observation_views, dependent: :destroy
  has_many :viewers, class_name: "User",
                     through: :observation_views,
                     source: :user

  # rubocop:disable Rails/ActiveRecordCallbacksOrder
  # else Rubocop says: "before_save is supposed to appear before before_destroy"
  # because a before_destroy must precede the has_many's
  before_save :cache_content_filter_data
  before_save :prefer_minimum_bounding_box_to_earth
  before_save :set_gps_dubious
  before_save :reconcile_collector_user
  before_create :default_collector_to_creator

  # rubocop:enable Rails/ActiveRecordCallbacksOrder
  after_update :notify_users_after_change
  after_update :update_occurrence_specimen_cache
  before_destroy :destroy_orphaned_collection_numbers
  before_destroy :notify_species_lists
  after_destroy :destroy_dependents
  after_destroy :cleanup_occurrence
  after_commit :flush_observation_change_emails, on: [:create, :update]

  # Automatically (but silently) log destruction.
  self.autolog_events = [:destroyed]

  SEARCHABLE_FIELDS = [
    :where, :text_name, :notes
  ].freeze

  # Eager-load tree every `Components::Matrix::Box` render of an
  # observation reaches into — image with vote/license/project/user
  # for `can_edit?`, location, name, namings (+ votes for
  # `Observation::NamingConsensus`), occurrence (+ observations for
  # the multi-obs occurrence link), projects, rss_log, user.
  # Shared by observations#index, field_slips show/index,
  # collection_numbers#show, herbarium_records#show, rss_logs#index,
  # sequences#new/edit, projects/updates#index, and the identify
  # queue (extends with `:observation_views`, `{ name: :synonym }`,
  # `{ namings: :name }`).
  #
  # Swap the `thumb_image:` hash for the matrix_box_carousels
  # alternative below when the carousel feature lands.
  def self.matrix_box_includes
    [{ thumb_image: [:image_votes, :license, :projects, :user] },
     # for matrix_box_carousels:
     # { images: [:image_votes, :license, :projects, :user] },
     { external_links: :external_site }, :location, :name,
     { namings: :votes },
     { occurrence: :observations }, :projects, :rss_log, :user]
  end

  # Subtree consumed by `Observation.show_includes`. The
  # `Descriptions::List#visible?` path reads each description's
  # `.user`, so `name: { descriptions: :user }` avoids N+1 per
  # description on the show page. The `observation_images: :image`
  # polymorphic preload skips the `images.delete` cascade query.
  def self.show_includes_tree
    [:collector_user,
     { collection_numbers: :user },
     { comments: Comment.index_includes_tree },
     { external_links: { external_site: { project: :user_group } } },
     { herbarium_records: [{ herbarium: :curators }, :user] },
     { images: [:image_votes, :license, :projects, :user] },
     { interests: :user },
     :location,
     { name: [{ synonym: :names }, { descriptions: :user },
              :interests, :description] },
     { namings: Naming.index_includes_tree },
     { observation_images: :image },
     :observation_collection_numbers,
     :observation_herbarium_records,
     :observation_views,
     :project_observations,
     :species_list_observations,
     { occurrence: [:field_slip, :observations] },
     { projects: [{ admin_group: :users }, :image] },
     :rss_log,
     { sequences: :user },
     { species_lists: [:location, :projects, :user] },
     :thumb_image,
     :user]
  end

  # Only the field-slip flow builds observations this way, so the
  # collector default-to-creator is always skipped: a foray recorder is
  # never auto-claimed as collector. The caller assigns the resolved
  # field-slip collector to the column afterward; a blank one stays blank
  # (suppressed on the show page). See #4211.
  def self.build_observation(location, name, notes, date, user)
    return nil unless location

    name ||= Name.find_by(text_name: "Fungi")
    now = Time.zone.now
    obs = new({ created_at: now, updated_at: now, source: "mo_website",
                when: date, user:, location:, name:, notes:,
                skip_collector_default: true })
    return nil unless obs

    obs.current_user = user

    obs.log(:log_observation_created, user: user)
    naming = Naming.user_construct({ name: }, obs, user)
    naming.save!
    naming.votes.create!(
      user:,
      observation: obs,
      value: Vote.maximum_vote,
      favorite: true
    )
    Observation::NamingConsensus.new(obs).calc_consensus(user)
    obs
  end

  # Normalize a resolved collector (User, free-text String, or nil) into
  # the column attributes. A User sets both the display string and the FK;
  # a string sets the free-text column; nil leaves both blank.
  def self.collector_attrs(collector)
    case collector
    when User
      { collector: collector.unique_text_name, collector_user_id: collector.id }
    when String
      collector.blank? ? {} : { collector: collector }
    else
      {}
    end
  end

  # "_user <ref>_" textile markup, where <ref> is a login or full name. The
  # closing "_" must be the delimiter (followed by a non-word char or
  # end-of-string) so logins/names with internal underscores survive
  # ("_user tyler_irvin_" -> "tyler_irvin"). Shared by the save-time collector
  # reconcile and the CollectorNotesSeeder backfill.
  COLLECTOR_USER_MARKUP = /_user\s+(.+?)_(?=\W|\z)/

  # Resolve a raw collector string to normalized column attributes:
  # { collector: <display string or nil>, collector_user_id: <id or nil> }.
  # Resolution order (first hit wins):
  #   1. blank                                   -> { nil, nil }
  #   2. "_user <ref>_" markup                   -> the referenced MO user
  #   3. the already-linked `existing` user      -> preserved (autocomplete
  #      selection / backfilled-claimed identity, matched by unique_text_name)
  #   4. the `owner` (login / name / unique_text_name)
  #   5. match_inat: a User#inat_username        -> that user
  #   6. an exact, unique login or name          -> that user
  #   7. otherwise                               -> free text, no FK
  # When a user is resolved, the display string is normalized to that
  # user's unique_text_name so the column stays consistent with the FK.
  # This is the EXACT resolver used on every save; the migration layers a
  # fuzzy owner-name match on top of a free-text result.
  def self.resolve_collector(raw, owner: nil, existing: nil, match_inat: false)
    string = raw.to_s.strip
    return { collector: nil, collector_user_id: nil } if string.blank?

    user = collector_user_for(string, owner:, existing:, match_inat:)
    return collector_attrs(user) if user

    { collector: string[0, 1024], collector_user_id: nil }
  end

  def self.collector_user_for(string, owner:, existing:, match_inat:)
    if (ref = string[COLLECTOR_USER_MARKUP, 1])
      return user_by_login_or_name(ref.strip)
    end

    preserved_collector_user(string, owner:, existing:) ||
      (match_inat && User.find_by(inat_username: string)) ||
      user_by_login_or_name(string)
  end

  # The already-linked user (autocomplete selection / backfilled-claimed
  # identity) or the owner, when the string still names them.
  def self.preserved_collector_user(string, owner:, existing:)
    return existing if existing && string == existing.unique_text_name
    return owner if owner && owner_strings(owner).include?(string)

    nil
  end

  def self.owner_strings(owner)
    [owner.login, owner.name, owner.unique_text_name].compact_blank
  end

  # A login (exact) or a name that is unique among users.
  def self.user_by_login_or_name(ref)
    ref = ref.to_s.strip
    return if ref.blank?

    User.find_by(login: ref) ||
      unique_name_match(ref) ||
      User.lookup_unique_text_name(ref)
  end

  # A name unique among users (so it identifies one person unambiguously).
  def self.unique_name_match(ref)
    named = User.where(name: ref)
    named.one? ? named.first : nil
  end

  def location?
    false
  end

  def observation?
    true
  end

  def can_edit?(user)
    Project.can_edit?(self, user) || is_collector?(user)
  end

  # A user is the collector when the linked FK is theirs. During the expand
  # window — before the backfill links the column and the contract migration
  # strips notes — fall back to the legacy notes[:Collector] markup so a
  # legacy collector keeps edit permission. Inert once notes are stripped.
  def is_collector?(user)
    return false unless user
    return collector_user_id == user.id if collector_user_id
    return false if collector.present?

    notes[:Collector].to_s.include?("_user #{user.login}_")
  end

  def project_admin?(user)
    Project.admin_power?(self, user)
  end

  # There is no value to keeping a collection number record after all its
  # observations are destroyed or removed from it.
  def destroy_orphaned_collection_numbers
    collection_numbers.each do |col_num|
      # SQL count so we don't lazy-load `col_num.observations`
      # under strict_loading.
      next if col_num.observations.where.not(id: id).exists?

      col_num.destroy_without_callbacks
    end
  end

  # Cache location and name data used by content filters.
  # `classification` cache was dropped in discussion #4163 — clade
  # filtering now reads it from `names.classification` directly.
  def cache_content_filter_data
    if name && name_id_changed?
      self.lifeform = name.lifeform
      self.text_name = name.text_name
    end
    return unless location_id_changed?

    if location
      self.where = location.name
      # Only cache coordinates for locations within the box_area threshold
      if location.box_area <= MO.obs_location_max_area
        self.location_lat = location.center_lat
        self.location_lng = location.center_lng
      else
        self.location_lat = nil
        self.location_lng = nil
      end
    else
      # Clear cached coordinates when location is removed
      # Don't clear where if it was explicitly set by the user
      self.where = nil unless where_changed?
      self.location_lat = nil
      self.location_lng = nil
    end
  end

  # This is meant to be run nightly to ensure that the cached name
  # and location data used by content filters is kept in sync.
  # `classification` is no longer cached on observations (discussion
  # #4163) — content filters read it from `names.classification`.
  def self.refresh_content_filter_caches(dry_run: false)
    refresh_cached_column(type: "name", foreign: "lifeform",
                          dry_run: dry_run) +
      refresh_cached_column(type: "name", foreign: "text_name",
                            dry_run: dry_run) +
      refresh_cached_column(type: "location", foreign: "name", local: "where",
                            dry_run: dry_run)
  end

  # Refresh a column which is a mirror of a foreign column.  Fixes all the
  # errors, and reports which ids were broken.
  def self.refresh_cached_column(type: nil, foreign: nil, local: foreign,
                                 dry_run: false)
    tbl = type.camelize.constantize.arel_table
    query = Observation.joins(type.to_sym).
            where(Observation[local.to_sym].not_eq(tbl[foreign.to_sym]))
    msgs = query.map do |obs|
      "Fixing #{type} #{foreign} for obs ##{obs.id}, " \
        "was #{obs.send(local).inspect}."
    end
    unless dry_run
      query.update_all(
        Observation[local.to_sym].eq(tbl[foreign.to_sym]).to_sql
      )
    end
    msgs
  end

  # Check for any observations whose consensus is a misspelled name.  This can
  # mess up the mirrors because misspelled names are "invisible", so their
  # classification and lifeform and such will not necessarily be kept up to
  # date.  Fixes and returns a messages for each one that was wrong.
  # Used by MiscDataRepairsJob
  def self.make_sure_no_observations_are_misspelled(dry_run: false)
    query = Observation.joins(:name).
            where(Name[:correct_spelling_id].not_eq(nil))
    msgs = query.pluck(Observation[:id], Name[:text_name]).
           map do |id, search_name|
             "Observation ##{id} was misspelled: #{search_name.inspect}"
           end
    unless dry_run
      query.update_all(
        Observation[:name_id].eq(Name[:correct_spelling_id]).to_sql
      )
    end
    msgs
  end

  # Use the original definition of `needs_id` to set the column values.
  # Used by MiscDataRepairsJob
  def self.refresh_needs_naming_column(dry_run: false)
    # Need to repeat `needs_naming:false` even though AR will optimize it out
    # and it'll only appear once in the resulting WHERE condition. Go figure.
    query = Observation.
            where(needs_naming: false).has_no_confident_name.
            or(where(needs_naming: false).with_name_above_genus)
    msgs = query.map do |obs|
      "Observation #{obs.id}, #{obs.text_name}, needs a name."
    end
    query.update_all(needs_naming: true) unless dry_run
    msgs
  end

  def update_view_stats(current_user = nil)
    super
    return if current_user.blank?

    @old_last_viewed_by ||= {}
    @old_last_viewed_by[current_user.id] = last_viewed_by(current_user)
    ObservationView.update_view_stats(id, current_user.id)
  end

  def last_viewed_by(user)
    observation_views.find_by(user: user)&.last_view
  end

  def old_last_viewed_by(user)
    @old_last_viewed_by && @old_last_viewed_by[user&.id]
  end

  # This allows Observation to override AR `touch` in this context only,
  # to cache a log_updated_at value
  def touch_when_logging
    self.log_updated_at = Time.zone.now
    save
  end

  ##############################################################################
  #
  #  :section: Location Stuff
  #
  ##############################################################################

  private

  # Use the eager-loaded `:location` when its id still matches
  # `location_id` (the show/index render path). Fall back to an FK
  # fetch when callers reach `place_name` after a `location_id =`
  # assignment invalidated the cached target, so we don't lazy-load
  # against strict_loading. (Overrides HasPlaceName's default, which
  # just calls the `location` association directly.)
  def location_for_place_name
    cached = association(:location).target if association(:location).loaded?
    return cached if cached && cached.id == location_id

    Location.find_by(id: location_id) if location_id
  end

  public

  # Useful for forms in which date is entered in YYYYMMDD format: When form tag
  # helper creates input field, it reads obs.when_str and gets date in
  # YYYYMMDD.  When form submits, assigning string to obs.when_str saves string
  # verbatim in @when_str, and if it is valid, sets the actual when field.
  # When you go to save the observation, it detects invalid format and prevents
  # save.  When it renders form again, it notes the error, populates the input
  # field with the old invalid string for editing, and colors it red.
  def when_str
    @when_str || self.when.strftime("%Y-%m-%d")
  end

  def when_str=(val)
    @when_str = val
    begin
      self.when = val if Date.parse(val)
    rescue ArgumentError
    end
  end

  def lat=(val)
    lat = Location.parse_latitude(val)
    lat = val if lat.nil? && val.present?
    self[:lat] = lat
  end

  def lng=(val)
    lng = Location.parse_longitude(val)
    lng = val if lng.nil? && val.present?
    self[:lng] = lng
  end

  def alt=(val)
    alt = Location.parse_altitude(val)
    alt = val if alt.nil? && val.present?
    self[:alt] = alt
  end

  # Kilometers of slack between an observation's GPS and its
  # location's bounding box before we consider the GPS "dubious" and
  # stop matching it in GPS-based searches (issue #4159). At 50 km
  # the false-positive rate from narrow location bboxes (tight trail
  # or park polygons with GPS from nearby photos) is low while clear
  # data errors (hemisphere flips, wrong country, lab-photo GPS) are
  # still caught.
  DUBIOUS_GPS_KM = 50

  # Is lat/lng more than DUBIOUS_GPS_KM from the location's bbox?
  # Reads the cached `gps_dubious` column when populated; falls back
  # to recomputing for unsaved/just-built records.
  def lat_lng_dubious?
    return compute_gps_dubious? if new_record? || gps_inputs_changed?

    gps_dubious
  end

  def compute_gps_dubious?
    return false unless lat && lng && location

    location.km_from_point(lat, lng) > DUBIOUS_GPS_KM
  end

  def gps_inputs_changed?
    will_save_change_to_attribute?(:lat) ||
      will_save_change_to_attribute?(:lng) ||
      will_save_change_to_attribute?(:location_id)
  end

  # Returns latitude if public or if the current user owns the observation.
  # The user should also be able to see hidden latitudes if they are an admin
  # or they are members of a project that the observation belongs to, but
  # those are harder to determine. This catches the majority of cases.
  def public_lat
    gps_hidden && user_id != @current_user&.id ? nil : lat
  end

  def public_lng
    gps_hidden && user_id != @current_user&.id ? nil : lng
  end

  def reveal_location?(user)
    !gps_hidden || can_edit?(user) || project_admin?(user)
  end

  def saved_change_to_place?
    saved_change_to_location_id? || saved_change_to_where?
  end

  ##############################################################################
  #
  #  :section: Notes
  #
  ##############################################################################
  #
  # Notes are arbitrary text supplied by the User.
  # They are read and written as a serialized Hash.
  #
  # The Hash keys are:
  #   - key(s) from the User's notes template, and
  #   - a general Other key supplied by the system.
  #
  # Keys with empty values are not saved.
  #
  # The notes template is a comma-separated list of arbitrary keys (except for
  # the following which are reserved for the system: "Other", "other", etc., and
  # translations thereof.
  # Sample observation.notes
  #  { }                                        no notes
  #  { Other: "rare" }                          generalized notes
  #  { Cap: "red", stem: "white" }              With only user-supplied keys
  #  { Cap: "red", stem: "white", Other: rare } both user-supplied and general
  #
  # The create Observation form displays separate fields for the keys in the
  # following order:
  #   - each key in the notes template, in the order listed in the template; and
  #   - Other.
  #
  # The edit Observation form displays separate fields in the following order:
  #   - each key in the notes template, in the order listed in the template;
  #   - each "orphaned" key -- one which is neither in the template nor Other;
  #   - Other.
  #
  # The show Observation view displays notes as follows, with Other underscored:
  #   no notes - nothing shown
  #   only generalized notes:
  #     Notes: value
  #   only user-supplied keys:
  #     Notes:
  #     First user key: value
  #     Second user key: value
  #     ...
  #   both user-supplied and general Other keys:
  #     Notes:
  #     First user key: value
  #     Second user key: value
  #     ...
  #     Other: value
  # Because keys with empty values are not saved in observation.notes, they are
  # not displayed with show Observaation.
  #
  # Notes are exported as shown, except that the intial "Notes:" caption is
  # omitted, and any markup is stripped from the keys.

  serialize :notes, coder: YAML

  # value of observation.notes if there are no notes
  def self.no_notes
    {}
  end

  def notes
    value = read_attribute(:notes)
    return Observation.no_notes unless value.is_a?(Hash)

    NormalizedHash.new(value)
  end

  # Notes to render on this observation's show page. For the primary
  # observation of a multi-member occurrence this is the per-key merge
  # across the occurrence (Occurrence#merged_notes), so the primary
  # surfaces its siblings' notes rather than only its own. Every other
  # case -- a non-primary sibling, or an observation not in an
  # occurrence -- shows its own notes unchanged.
  def display_notes
    return notes unless shows_merged_notes?

    occurrence.merged_notes
  end

  # True only for the primary observation of an occurrence that has more
  # than one member -- the one case where the show page merges notes.
  def shows_merged_notes?
    occ = occurrence
    occ.present? && occ.primary_observation_id == id &&
      occ.observations.many?
  end

  # Key used for general Observation.notes
  # (notes which were not entered in a notes_template field)
  def self.other_notes_key
    :Other
  end

  # convenience wrapper around class method of same name
  delegate :other_notes_key, to: :Observation

  # other_notes_key as a String
  # Makes it easy to combine with notes_template
  def self.other_notes_part
    other_notes_key.to_s
  end

  delegate :other_notes_part, to: :Observation

  def other_notes
    notes ? notes[other_notes_key] : nil
  end

  def other_notes=(val)
    self.notes ||= {}
    notes[other_notes_key] = val
  end

  # id of view textarea for a Notes heading. Used in tests
  def self.notes_part_id(part)
    "#{notes_area_id_prefix}#{part.tr(" ", "_")}"
  end

  delegate :notes_part_id, to: :Observation

  # prefix for id of textarea
  def self.notes_area_id_prefix
    "observation_notes_"
  end

  # value of notes part
  #   notes: { Other: abc }
  #   observation.notes_part_value("Other") #=> "abc"
  #   observation.notes_part_value(:Other)  #=> "abc"
  def notes_part_value(part)
    notes.blank? ? "" : notes[notes_normalized_key(part)]
  end

  # Change spaces to underscores in keys
  #   notes_normalized_key("Nearby trees") #=> :Nearby_trees
  #   notes_normalized_key(:Other)         #=> :Other
  def self.notes_normalized_key(part)
    part.to_s.tr(" ", "_").to_sym
  end

  delegate :notes_normalized_key, to: :Observation

  # Array of note parts (Strings) to display in create & edit form,
  # in following (display) order. Used by views.
  #   notes_template fields
  #   orphaned fields (field in obs, but not in notes_template, not "Other")
  #   "Other"
  # Example outputs:
  #   ["Other"]
  #   ["orphaned_part", "Other"]
  #   ["template_1st_part", "template_2nd_part", "Other"]
  #   ["template_1st_part", "template_2nd_part", "orphaned_part", "Other"]
  def form_notes_parts(user)
    return user.notes_template_parts + [other_notes_part] if notes.blank?

    user.notes_template_parts + notes_orphaned_parts(user) +
      [other_notes_part]
  end

  # Array of notes parts (Strings) which are
  # neither in the notes_template nor the caption for other notes
  # Note that underscores (_) get translated to spaces ( ) here.
  def notes_orphaned_parts(user)
    return [] if notes.blank?

    # Normalization for comparison (lowercase)
    normalize_for_comparison = ->(key) { normalize_for_display(key).downcase }

    known_keys = (user.notes_template_parts + [other_notes_part]).
                 map(&normalize_for_comparison).
                 to_set
    notes.keys.each_with_object([]) do |key, result|
      normalized_key = normalize_for_comparison.call(key)
      next if known_keys.include?(normalized_key)

      result << normalize_for_display(key)
      known_keys << normalized_key
    end
  end

  # notes as a String, captions (keys) without added formstting,
  # omitting "Other" if it's the only caption.
  #  notes: {}                                 ::=> ""
  #  notes: { Other: "abc" }                   ::=> "abc"
  #  notes: { cap: "red" }                     ::=> "cap: red"
  #  notes: { cap: "red", stem: , Other: "x" } ::=> "cap: red
  #                                                  stem:
  #                                                  Other: x"
  def self.export_formatted(notes, markup = nil)
    return "" if notes.blank?

    return notes[other_notes_key] if notes.keys == [other_notes_key]

    result = notes.each_with_object(+"") do |(key, value), str|
      str << "#{markup}#{key.to_s.tr("_", " ")}#{markup}: #{value}\n"
    end
    result.chomp
  end

  # wraps Class method with slightly different name
  def notes_export_formatted
    Observation.export_formatted(notes)
  end

  # Notes (or other hash) as a String, captions (keys) with added formstting,
  # omitting "Other" if it's the only caption.
  #
  # Used in views which display notes
  #  notes: {}                                 => ""
  #  notes: { Other: "abc" }                   => "abc"
  #  notes: { cap: "red" }                     => "+cap+: red"
  #  notes: { cap: "red", stem: , other: "x" } => "+cap+: red
  #                                                +stem+:
  #                                                +Other+: x"
  def self.show_formatted(notes)
    export_formatted(notes, "+")
  end

  # wraps Class method with slightly different name
  def notes_show_formatted
    Observation.show_formatted(notes)
  end

  ##############################################################################
  #
  #  :section: Name Formats
  #
  ##############################################################################

  # Name in plain text with id to make it unique, never nil.
  def unique_text_name(user = nil)
    string_with_id(name.real_search_name(user))
  end

  # Textile-marked-up name, never nil. `user` is who's *looking* (nil
  # => no viewer-specific formatting).
  def format_name(user = nil)
    name.observation_name(user)
  end

  # Plain-text title for the browser tab `<title>`. `text_name` is
  # the denormalized binomial-only column — no author, no id, no
  # markup. The title helper prepends "OBSERVATION <id>:" so we
  # don't need those here. (The visible page heading is built by
  # `header/title_helper#page_title_for` via
  # `Observations::ConsensusNameLink` — wraps the consensus name
  # in a link, which is view-layer work that can't live cleanly on
  # the model.)
  def document_title
    text_name
  end

  # Textile-marked-up name with id to make it unique, never nil.
  def unique_format_name(user = nil)
    string_with_id(name.observation_name(user))
  rescue StandardError
    ""
  end

  ##############################################################################
  #
  #  :section: Namings and Votes
  #
  ##############################################################################

  # Dump out the situation as the observation sees it.  Useful for debugging
  # problems with reloading requirements.
  def dump_votes
    namings.map do |n|
      str = "#{n.id} #{n.name.real_search_name}: "
      if n.votes.empty?
        str += "no votes"
      else
        votes = n.votes.map do |v|
          "#{v.user.login}=#{v.value}" + (v.favorite ? "(*)" : "")
        end
        str += votes.join(", ")
      end
      str
    end.join("\n")
  end

  ##############################################################################
  #
  #  :section: Images
  #
  ##############################################################################

  # Add Image to this Observation, making it the thumbnail if none set already.
  # Saves changes.  Returns Image.
  def add_image(img)
    unless images.include?(img)
      images << img
      self.thumb_image = img unless thumb_image
      self.updated_at = Time.zone.now
      track_change(:added_image)
      save
      reload
    end
    img
  end

  # List of images attached to this Observation, sorted
  # for the show/edit pages with the thumb_image first
  def images_sorted
    images.sort_by do |img|
      img.id == thumb_image_id ? -1 : img.id
    end
  end

  # Removes an Image from this Observation.  If it's the thumbnail, changes
  # thumbnail to next available Image.  Saves change to thumbnail, might save
  # change to Image.  Returns Image.
  def remove_image(img)
    if images.include?(img) || thumb_image_id == img.id
      images.delete(img)
      track_change(:removed_image)
      if thumb_image_id == img.id
        update(thumb_image: next_thumb_image)
      else
        # Touch to trigger after_commit within proper transaction flow
        touch
      end
    end
    img
  end

  # Next thumbnail candidate: oldest own image first, then occurrence
  def next_thumb_image
    own = images.loaded? ? images.min_by(&:id) : images.order(:id).first
    return own if own
    return nil unless occurrence

    Image.joins(:observation_images).
      where(observation_images: {
              observation_id: Observation.where(occurrence_id: occurrence_id).
                              where.not(id: id).select(:id)
            }).
      order(:id).first
  end

  # Determines if an obs can have the Naming "_Imageless_"
  # N+1: maybe move method to NamingConsensus and
  # Add species_lists and herbarium_records to naming_includes
  def has_backup_data?
    !thumb_image_id.nil? ||
      species_lists.any? ||
      herbarium_records.any? ||
      specimen ||
      notes.length >= 100
  end

  ##############################################################################
  #
  #  :section: Specimens
  #
  ##############################################################################

  def turn_off_specimen_if_no_more_records
    return unless specimen
    # SQL `exists?` instead of loading the associations — keeps
    # the caller from needing to `.reload` (which would drop the
    # `show_includes` eager-loads from the strict-loading scope).
    return if observation_collection_numbers.exists?
    return if observation_herbarium_records.exists?
    return if sequences.exists?
    return if field_slip_id

    update(specimen: false)
  end

  ##############################################################################
  #
  #  :section: Sources
  #
  ##############################################################################

  # Which agent created this observation?
  # The `mo_inat_import` value (5) was retired in #4209; imported
  # observations are now identified by `import_link.present?` (#4299),
  # not by an entry-agent enum value.
  enum :source, {
    mo_website: 1,
    mo_android_app: 2,
    mo_iphone_app: 3,
    mo_api: 4
  }

  # Message to use to credit the source of this observation.
  # External imports take precedence over the entry agent: an obs
  # synced from iNat surfaces as "Imported from iNaturalist" even if
  # the user originally created it via mo_website. Returns nil only
  # when neither an import_link nor a source enum value is present.
  # Intended for use with .tpl to render as HTML:
  #   <%= observation.source_credit.tpl %>
  def source_credit
    if (link = import_link)
      :source_credit_external.l(name: link.external_site.name,
                                url: link.link_url)
    elsif source.present?
      :"source_credit_#{source}"
    end
  end

  # The ExternalLink (if any) recording where this observation was imported
  # from — the external-source axis of #4208 (#4299). At most one per obs.
  # Uses the loaded `external_links` association when present (matrix box,
  # show page) to avoid a query; otherwise queries only the import row.
  def import_link
    if external_links.loaded?
      external_links.detect(&:import?)
    else
      external_links.import.first
    end
  end

  # Structured form of source_credit for external imports — returns
  # { text:, url: } so renderers can build the link element with
  # whatever attributes they need (e.g. target="_blank" for off-site).
  # Returns nil for non-imported observations; callers fall back to
  # source_credit (textile / enum) in that case.
  def external_credit_link
    return nil unless (link = import_link)

    {
      text: :source_credit_external_text.l(name: link.external_site.name),
      url: link.link_url,
      external_id: link.external_id
    }
  end

  # Do we want to prominently advertise the source of this observation?
  # An import link makes it noteworthy; otherwise a non-website entry agent.
  def source_noteworthy?
    return true if import_link.present?

    source.present? && source != "mo_website"
  end

  ##############################################################################
  #
  #  :section: Callbacks
  #
  ##############################################################################

  # Callback that updates a User's contribution after adding an Observation to
  # a SpeciesList.
  def add_spl_callback(spl)
    tmp_id = user_id
    tmp_id ||= spl.user_id if spl.respond_to?(:user_id)
    UserStats.update_contribution(:add, :species_list_entries, tmp_id)
  end

  # Callback that updates a User's contribution after removing an Observation
  # from a SpeciesList.
  def remove_spl_callback(spl)
    tmp_id = user_id
    tmp_id ||= spl.user_id if spl.respond_to?(:user_id)
    UserStats.update_contribution(:del, :species_list_entries, tmp_id)
  end

  # Callback that logs an Observation's destruction on all of its
  # SpeciesList's.  (Also saves list of Namings so they can be destroyed
  # by hand afterword without causing superfluous calc_consensuses.)
  def notify_species_lists
    # Tell all the species_lists it belonged to.
    species_lists.each do |spl|
      spl.log(:log_observation_destroyed2, user: current_user,
                                           name: unique_format_name,
                                           touch: false)
    end

    # Save namings so we can delete them after it's dead.
    @old_namings = namings
  end

  # Callback that destroys an Observation's Naming's (carefully) after the
  # Observation is destroyed.
  def destroy_dependents
    @old_namings.each do |naming|
      naming.current_user = naming.observation.current_user
      naming.observation = nil # (tells it not to recalc consensus)
      naming.destroy
    end
  end

  # Callback that tracks which fields changed for email notifications.
  def notify_users_after_change
    track_change(:date) if saved_change_to_when?
    track_change(:location) if saved_change_to_place?
    track_change(:notes) if saved_change_to_notes?
    track_change(:specimen) if saved_change_to_specimen?
    track_change(:thumb_image_id) if saved_change_to_thumb_image_id?
    return unless saved_change_to_is_collection_location?

    track_change(:is_collection_location)
  end

  # Callback that sends destroy notification before observation is destroyed.
  # This must be sent immediately since the observation won't exist after.
  def notify_users_before_destroy
    send_observation_destroyed_emails
  end

  # Update occurrence's cached has_specimen when specimen changes.
  def update_occurrence_specimen_cache
    return unless saved_change_to_specimen? && occurrence

    occurrence.recompute_has_specimen!
  end

  # Clean up occurrence after an observation is destroyed.
  # Reassigns default if needed, then destroys if < 2 obs remain.
  def cleanup_occurrence
    return unless occurrence_id

    occ = Occurrence.find_by(id: occurrence_id)
    return unless occ

    reassign_occurrence_primary(occ) if occ.primary_observation_id == id
    return unless Occurrence.exists?(occ.id)

    occ.reload
    occ.destroy_if_incomplete!
  end

  # When an observation moves to a new occurrence, clean up the old one.
  def cleanup_old_occurrence(old_occ, new_occ)
    return unless old_occ && old_occ.id != new_occ.id

    old_occ.reload
    reassign_occurrence_primary(old_occ) if old_occ.primary_observation_id == id
    return unless Occurrence.exists?(old_occ.id)

    old_occ.reload
    old_occ.destroy_if_incomplete!
  end

  def reassign_occurrence_primary(occ)
    next_obs = occ.observations.order(:created_at).first
    if next_obs
      occ.update!(primary_observation: next_obs)
    else
      occ.destroy!
    end
  end

  # Track a pending change for email notification batching.
  # Uses Thread.current for thread safety across concurrent requests.
  def track_change(change_type)
    key = pending_changes_key
    Thread.current[key] ||= []
    return if Thread.current[key].include?(change_type)

    Thread.current[key] << change_type
  end

  # Returns and clears the list of pending changes.
  def pending_changes
    key = pending_changes_key
    changes = Thread.current[key] || []
    Thread.current[key] = nil
    changes
  end

  # Unique key per observation instance for thread-local storage.
  def pending_changes_key
    :"observation_#{id}_pending_changes"
  end

  # Send batched observation change emails. Called after all changes are made.
  # Migrated from QueuedEmail::ObservationChange to deliver_later.
  def flush_observation_change_emails
    changes = pending_changes
    return if changes.empty?

    sender = user
    recipients = interested_users - [sender]
    note = changes.join(",")

    recipients.each do |receiver|
      next if receiver.no_emails

      ObservationChangeMailer.build(
        sender:, receiver:, observation: self, note:, time: updated_at
      ).deliver_later
    end
  end

  # Send immediate destroy notification (can't batch - obs is being deleted).
  def send_observation_destroyed_emails
    sender = user
    recipients = interested_users - [sender]
    note = unique_format_name(current_user)

    recipients.each do |receiver|
      next if receiver.no_emails

      ObservationChangeMailer.build(
        sender:, receiver:, observation: nil, note:, time: Time.zone.now
      ).deliver_later
    end
  end

  # Get list of users interested in this observation (for email notifications).
  def interested_users
    interests.select(&:state).filter_map(&:user).uniq
  end

  # Send email notifications upon change to consensus.
  #
  #   old_name = obs.name
  #   obs.name = new_name
  #   obs.announce_consensus_change(old_name, new_name, current_user)
  #
  # `current_user` may be nil (e.g. an automated consensus recalculation
  # with no attributable acting user) - `user_log_consensus_change` and
  # `ConsensusChangeMailer`'s sender both handle that.
  def announce_consensus_change(old_name, new_name, current_user)
    user_log_consensus_change(old_name, new_name, current_user)

    # Change can trigger emails.
    owner  = user
    sender = current_user
    recipients = []

    # Tell owner of observation if they want.
    recipients.push(owner) if owner&.email_observations_consensus

    # Send to people who have registered interest.
    # Also remove everyone who has explicitly said they are NOT interested.
    interests.each do |interest|
      if interest.state
        recipients.push(interest.user)
      else
        recipients.delete(interest.user)
      end
    end

    # Remove users who have opted out of all emails.
    recipients.reject!(&:no_emails)

    # Send notification to all except the person who triggered the change.
    (recipients.uniq - [sender]).each do |receiver|
      ConsensusChangeMailer.build(
        sender:, receiver:, observation: self, old_name:, new_name:
      ).deliver_later
    end
  end

  def user_log_consensus_change(old_name, new_name, current_user)
    if old_name
      log(:log_consensus_changed, user: current_user,
                                  old: old_name.display_name(current_user),
                                  new: new_name.display_name(current_user))
    else
      log(:log_consensus_created, user: current_user,
                                  name: new_name.display_name(current_user))
    end
  end

  # After defining a location, update any lists using old "where" name.
  def self.define_a_location(location, old_name)
    old_name = connection.quote(old_name)
    new_name = connection.quote(location.name)
    connection.update(%(
      UPDATE observations
      SET `where` = #{new_name}, location_id = #{location.id}
      WHERE `where` = #{old_name}
    ))
  end

  ##############################################################################
  #
  #  :section: Field Slips
  #
  ##############################################################################

  # Textile-marked-up collector for field-slip rendering: a `_user_`
  # link when an MO user is known, else the plain `collector` string, else
  # the legacy notes[:Collector] during the expand window (so an un-backfilled
  # obs still renders its collector — inert once notes are stripped), else
  # nil (a field slip with no recorded collector renders blank). See #4211.
  def collector_textile
    return collector_user.textile_name if collector_user
    return collector if collector.present?

    notes[:Collector].presence
  end

  # True when the collector identity differs from the user who entered
  # the record (foray recorder enters on a collector's behalf, or an
  # import where the importer differs from the iNat collector). Drives
  # the "Entered by:" secondary label on the show page.
  def collector_differs_from_creator?
    if collector_user_id
      collector_user_id != user_id
    elsif collector.present?
      collector != user&.unique_text_name
    else
      false
    end
  end

  # True when no collector identity is recorded and the observation came
  # from a field slip — a foray recorder entered it but the collector was
  # not captured here (it is written on the physical slip). The show page
  # suppresses the "Collector:" line in this case rather than falsely
  # claiming the entering user, leaving only "Entered by:". See #4211.
  def collector_unrecorded?
    collector.blank? && collector_user_id.nil? && field_slip_id.present?
  end

  def field_slip_name
    return notes[:Field_Slip_ID] if notes.include?(:Field_Slip_ID)

    "_name #{name.text_name}_"
  end

  def field_slip_id_by
    return notes[:Field_Slip_ID_By] if notes.include?(:Field_Slip_ID_By)

    # `pick(:user_id)` reads the column directly, avoiding the
    # `namings.find_by(...).user` chain that would trip strict
    # loading on the form autocompleter render path. Filter by
    # `name_id` so we don't touch the `:name` association either.
    user_id = namings.where(name_id:).pick(:user_id)
    return "" unless user_id

    User.find_by(id: user_id)&.textile_name || ""
  end

  def other_codes
    return notes[:Other_Codes] if notes.include?(:Other_Codes)

    ""
  end

  ##############################################################################

  protected

  include Validations # currently only `validate_when`

  validate :check_requirements, :check_when

  def check_requirements
    check_where
    check_user
    check_coordinates
    check_hidden

    return unless @when_str

    begin
      Date.parse(@when_str)
    rescue ArgumentError
      if /^\d{4}-\d{1,2}-\d{1,2}$/.match?(@when_str)
        errors.add(:when_str, :runtime_date_invalid.t)
      else
        errors.add(:when_str, :runtime_date_should_be_yyyymmdd.t)
      end
    end
  end

  def check_where
    # Clean off leading/trailing whitespace from +where+.
    self.where = where.strip_squeeze if where
    self.where = nil if where == ""

    if where.to_s.blank? && !location_id
      self.location = Location.unknown
      # errors.add(:where, :validate_observation_where_missing.t)
    elsif where.to_s.size > 1024
      errors.add(:where, :validate_observation_where_too_long.t)
    end
  end

  def check_user
    return if user || @current_user

    errors.add(:user, :validate_observation_user_missing.t)
  end

  def check_coordinates
    check_latitude
    check_longitude
    check_altitude
  end

  def check_latitude
    if lat.blank? && lng.present? ||
       lat.present? && !Location.parse_latitude(lat)
      errors.add(:lat, :runtime_lat_long_error.t)
    end
  end

  def check_longitude
    if lat.present? && lng.blank? ||
       lng.present? && !Location.parse_longitude(lng)
      errors.add(:lng, :runtime_lat_long_error.t)
    end
  end

  def check_altitude
    return unless alt.present? && !Location.parse_altitude(alt)

    # As of July 5, 2020 this statement appears to be unreachable
    # because .to_i returns 0 for unparsable strings.
    errors.add(:alt, :runtime_altitude_error.t)
  end

  def check_hidden
    return unless location&.hidden

    self.gps_hidden = true
  end

  def check_when
    self.when ||= Time.zone.now
    validate_when(self.when, errors)
  end

  private

  def normalize_for_display(key)
    key.to_s.tr("_", " ")
  end

  def prefer_minimum_bounding_box_to_earth
    return unless location && Location.is_unknown?(location.name) &&
                  lat.present? && lng.present?

    self.location =
      Location.
      with_minimum_bounding_box_containing_point(lat: lat, lng: lng).
      # Use the unknown location if there's no minimum bounding box.
      # NOTE: jdc As of 20241105, that's possible because the live db unknown
      # location does not contain the entire globe. Its boundaries:
      #             north: 89,
      #  west: -179,          east: 179,
      #            south: -89,
      # Also see ObservationAPI#prefer_minimum_bounding_box_to_earth!
      presence || Location.unknown
  end

  # Keeps the cached `gps_dubious` column in sync on save. Gates the
  # re-computation on attribute changes so untouched obs don't pay the
  # recompute cost on every save.
  def set_gps_dubious
    return unless new_record? || gps_inputs_changed?

    self.gps_dubious = compute_gps_dubious?
  end

  # Native observations default the collector to the entering user, at
  # creation only — so merely viewing/editing a legacy row (collector
  # still null) never silently rewrites it. Imports and explicit form
  # values arrive non-blank and skip this. See #4211.
  def default_collector_to_creator
    return if collector.present? || skip_collector_default

    self.collector = user&.unique_text_name
    self.collector_user_id = user_id
  end

  # When the collector string changes, re-resolve it through the shared
  # resolver: "_user <ref>_" markup, a bare login/name, the existing linked
  # user (preserving an autocomplete selection or backfilled/claimed
  # identity), or the creator all link the FK; anything else is kept as
  # free text with the FK cleared. The resolver also normalizes the display
  # string to the linked user's unique_text_name. An unchanged collector
  # (e.g. a view-stats save) is left untouched.
  def reconcile_collector_user
    return unless will_save_change_to_attribute?(:collector) ||
                  will_save_change_to_attribute?(:collector_user_id)

    resolved = self.class.resolve_collector(collector, owner: user,
                                                       existing: collector_user)
    self.collector = resolved[:collector]
    self.collector_user_id = resolved[:collector_user_id]
  end
end
