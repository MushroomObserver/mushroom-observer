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
#  inat_id:                 iNaturalist id of corresponding Observation
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
  attr_accessor :current_user

  include Scopes

  belongs_to :thumb_image, class_name: "Image",
                           inverse_of: :thumb_glossary_terms
  belongs_to :name # (used to cache consensus name)
  belongs_to :location
  belongs_to :rss_log
  belongs_to :user

  # Has to go before "has many interests" or interests will be destroyed
  # before it has a chance to notify the interested users of the destruction.
  before_destroy :notify_users_before_destroy

  has_many :votes
  has_many :comments,  as: :target, dependent: :destroy, inverse_of: :target
  has_many :interests, as: :target, dependent: :destroy, inverse_of: :target
  has_many :sequences, dependent: :destroy
  has_many :external_links, dependent: :destroy

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
  has_many :field_slips, dependent: :destroy

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

  # rubocop:enable Rails/ActiveRecordCallbacksOrder
  after_update :notify_users_after_change
  before_destroy :destroy_orphaned_collection_numbers
  before_destroy :notify_species_lists
  after_destroy :destroy_dependents
  after_commit :flush_observation_change_emails, on: [:create, :update]

  # Automatically (but silently) log destruction.
  self.autolog_events = [:destroyed]

  SEARCHABLE_FIELDS = [
    :where, :text_name, :notes
  ].freeze

  def self.build_observation(location, name, notes, date, current_user = nil)
    return nil unless location

    name ||= Name.find_by(text_name: "Fungi")
    now = Time.zone.now
    user = current_user || User.current
    obs = new({ created_at: now, updated_at: now, source: "mo_website",
                when: date,
                user:, location:, name:, notes: })
    return nil unless obs

    obs.user_log(user, :log_observation_created)
    naming = Naming.user_construct({ name: }, obs, user)
    naming.save!
    naming.votes.create!(
      user:,
      observation: obs,
      value: Vote.maximum_vote,
      favorite: true
    )
    Observation::NamingConsensus.new(obs).user_calc_consensus(user)
    obs
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

  def is_collector?(user)
    user && notes[:Collector]&.include?("_user #{user.login}_")
  end

  def project_admin?(user = User.current)
    Project.admin_power?(self, user)
  end

  # There is no value to keeping a collection number record after all its
  # observations are destroyed or removed from it.
  def destroy_orphaned_collection_numbers
    collection_numbers.each do |col_num|
      col_num.destroy_without_callbacks if col_num.observations == [self]
    end
  end

  # Cache location and name data used by content filters.
  def cache_content_filter_data
    if name && name_id_changed?
      self.lifeform = name.lifeform
      self.text_name = name.text_name
      self.classification = name.classification
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
      # Clear cached data when location is removed
      self.where = nil
      self.location_lat = nil
      self.location_lng = nil
    end
  end

  # This is meant to be run nightly to ensure that the cached name
  # and location data used by content filters is kept in sync.
  def self.refresh_content_filter_caches(dry_run: false)
    refresh_cached_column(type: "name", foreign: "lifeform",
                          dry_run: dry_run) +
      refresh_cached_column(type: "name", foreign: "text_name",
                            dry_run: dry_run) +
      refresh_cached_column(type: "name", foreign: "classification",
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
  # Used by refresh_caches script
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
  # Used by refresh_caches script
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

  def update_view_stats(current_user = User.current)
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

  # Abstraction over +where+ and +location.display_name+.  Returns Location
  # name as a string, preferring +location+ over +where+ wherever both exist.
  # Also applies the location_format of the current user (defaults to "postal").
  def place_name
    if location
      location.display_name
    elsif User.current_location_format == "scientific"
      Location.reverse_name(where)
    else
      where
    end
  end

  # Set +where+ or +location+, depending on whether a Location is defined with
  # the given +display_name+.  (Fills the other in with +nil+.)
  # Adjusts for the current user's location_format as well.
  def place_name=(place_name)
    where = Location.normalize_place_name(place_name)
    loc = Location.find_by_name(where)
    if loc
      self.where = loc.name
      self.location = loc
    else
      self.where = where
      self.location = nil
    end
  end

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

  # Is lat/lng more than 10% outside of location extents?
  def lat_lng_dubious?
    lat && location && !location.lat_lng_close?(lat, lng)
  end

  def place_name_and_coordinates
    if lat.present? && lng.present?
      lat_string = format_coordinate(lat, "N", "S")
      lng_string = format_coordinate(lng, "E", "W")
      "#{place_name} (#{lat_string} #{lng_string})"
    else
      place_name
    end
  end

  def format_coordinate(value, positive_point, negative_point)
    return "#{-value.round(4)}°#{negative_point}" if value.negative?

    "#{value.round(4)}°#{positive_point}"
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

  def display_lat_lng
    return "" unless lat

    "#{lat.abs}°#{lat.negative? ? "S" : "N"} " \
      "#{lng.abs}°#{lng.negative? ? "W" : "E"}"
  end

  def display_alt
    return "" unless alt

    "#{alt.round}m"
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

    # Defensive check: if notes is not a Hash, it might be misaligned columns
    # Only reject types that indicate column misalignment (Time/DateTime)
    # Allow other types to fail naturally with better error messages
    if notes.is_a?(Time) || notes.is_a?(DateTime)
      Rails.logger.warn(
        "export_formatted received #{notes.class} instead of Hash. " \
        "This may indicate column misalignment. Returning empty string."
      )
      return ""
    end

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
  def unique_text_name
    string_with_id(name.real_search_name)
  end

  def user_unique_text_name(user)
    string_with_id(name.user_real_search_name(user))
  end

  # Textile-marked-up name, never nil.
  def format_name
    name.user_observation_name(User.current)
  end

  def user_format_name(user)
    name.user_observation_name(user)
  end

  # Textile-marked-up name with id to make it unique, never nil.
  def unique_format_name
    string_with_id(name.observation_name)
  rescue StandardError
    ""
  end

  def user_unique_format_name(user)
    string_with_id(name.user_observation_name(user))
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
        update(thumb_image: images.empty? ? nil : images.first)
      else
        # Touch to trigger after_commit within proper transaction flow
        touch
      end
    end
    img
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
    return unless collection_numbers.empty?
    return unless herbarium_records.empty?
    return unless sequences.empty?
    return unless field_slips.empty?

    update(specimen: false)
  end

  ##############################################################################
  #
  #  :section: Sources
  #
  ##############################################################################

  # Which agent created this observation?
  enum :source, {
    mo_website: 1,
    mo_android_app: 2,
    mo_iphone_app: 3,
    mo_api: 4,
    mo_inat_import: 5
  }

  # Message to use to credit the agent which created this observation.
  # Intended to be used with .tpl to render as HTML:
  #   <%= observation.source_credit.tpl %>
  def source_credit
    :"source_credit_#{source}" if source.present?
  end

  # Do we want to prominantly advertise the source of this observation?
  def source_noteworthy?
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
      spl.log(:log_observation_destroyed2, name: unique_format_name,
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
    note = user_unique_format_name(User.current)

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
  #   obs.announce_consensus_change(old_name, new_name)
  #
  def announce_consensus_change(old_name, new_name)
    log_consensus_change(old_name, new_name)

    # Change can trigger emails.
    owner  = user
    sender = User.current
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

  def user_announce_consensus_change(old_name, new_name, current_user)
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

  def log_consensus_change(old_name, new_name)
    if old_name
      log(:log_consensus_changed, old: old_name.display_name,
                                  new: new_name.display_name)
    else
      log(:log_consensus_created, name: new_name.display_name)
    end
  end

  def user_log_consensus_change(old_name, new_name, current_user)
    if old_name
      user_log(current_user, :log_consensus_changed,
               { old: old_name.user_display_name(current_user),
                 new: new_name.user_display_name(current_user) })
    else
      user_log(current_user, :log_consensus_created,
               { name: new_name.user_display_name(current_user) })
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

  def collector
    return notes[:Collector] if notes.include?(:Collector)
    return notes[:collector] if notes.include?(:collector)
    return notes[:"Collector's_Name"] if notes.include?(:"Collector's_Name")
    return notes[:"Collector's_name"] if notes.include?(:"Collector's_name")
    return notes[:"Collector(s)"] if notes.include?(:"Collector(s)")

    user.textile_name
  end

  def field_slip_name
    return notes[:Field_Slip_ID] if notes.include?(:Field_Slip_ID)

    "_name #{name.text_name}_"
  end

  def field_slip_id_by
    return notes[:Field_Slip_ID_By] if notes.include?(:Field_Slip_ID_By)

    naming = namings.find_by(name:)
    return naming.user.textile_name if naming

    ""
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
end
