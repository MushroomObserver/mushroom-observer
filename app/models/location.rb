# frozen_string_literal: true

#
#  = Location Model
#
#  Model to describe a location.  Locations are rectangular regions, not
#  points, with an associated free-form description.
#
#  == Version
#
#  Changes are kept in the "location_versions" table using
#  ActiveRecord::Acts::Versioned.
#
#  == Attributes
#
#  id::           (-) Locally unique numerical id, starting at 1.
#  created_at::   (-) Date/time it was first created.
#  updated_at::   (V) Date/time it was last updated.
#  user::         (V) User that created it.
#  version::      (V) Version number.
#  ---
#  name::         (V) Name, e.g.: "Lacy Park, Los Angeles Co., California, USA"
#  north::        (V) North edge in degrees north, e.g. 37.8233
#  south::        (V) South edge in degrees north, e.g. 37.8035
#  east::         (V) East edge in degrees east, e.g. -122.173
#  west::         (V) West edge in degrees east, e.g. -122.204
#  high::         (V) Maximum elevation in meters, e.g. 100
#  low::          (V) Minimum elevation in meters, e.g. 0
#  notes::        (V) Arbitrary extra notes supplied by User.
#  hidden::       (V) Should observation with this location be hidden
#  box_area::     (-) Area of the box in square kilometers.
#
#  ('V' indicates that this attribute is versioned in past_locations table.)
#
#  == Class methods
#
#  clean_name::         Clean a name before doing searches on it.
#
#  == Scopes
#
#  created_at("yyyy-mm-dd", "yyyy-mm-dd")
#  updated_at("yyyy-mm-dd", "yyyy-mm-dd")
#  name_has(place_name)
#  region(place_name)
#  in_box(north:, south:, east:, west:)
#
#  == Instance methods
#
#  interests::          Interests in this Location.
#  observations::       Observations at this Location.
#  species_lists::      SpeciesLists at this Location.
#  herbaria::           Herbaria at this location (typically no more than one).
#  users::              Users who have claimed this as their profile location.
#
#  ==== Lat/long methods
#  north_west::         [north, west]
#  north_east::         [north, east]
#  south_west::         [south, west]
#  south_east::         [south, east]
#  center::             [n+s/2, e+w/2]
#  tweak::              Expand extents to include the given point.
#  parse_latitude::     Validate and parse latitude from a string.
#  parse_longitude::    Validate and parse longitude from a string.
#  parse_altitude::     Validate and parse altitude from a string.
#  found_here?::        Was the given obs found here?
#
#  ==== Name methods
#  display_name::       +name+ reformated based on user's preference.
#  text_name::          Plain-text version of +display_name+.
#  format_name::        Alias for +display_name+ (for compatibility).
#  unique_text_name::   (same thing, with id tacked on to make unique)
#  unique_format_name:: (same thing, with id tacked on to make unique)
#
#  ==== Attachments
#  versions::           Old versions.
#  description::        Main LocationDescription.
#  descriptions::       Alternate LocationDescription's.
#  interests::          Interests in this Location.
#  observations::       Observations using this Location as consensus.
#  mergable?::          Is it safe to merge this Location into another.
#
#  == Callbacks
#
#  create_description:: After create: create (empty) official NameDescription.
#  notify_users::       After save: send email notification.
#
################################################################################
class Location < AbstractModel # rubocop:disable Metrics/ClassLength
  require("acts_as_versioned")

  include Scopes

  belongs_to :description, class_name: "LocationDescription" # (main one)
  belongs_to :rss_log
  belongs_to :user

  has_many :descriptions, -> { order(num_views: :desc) },
           class_name: "LocationDescription",
           inverse_of: :location
  has_many :comments,  as: :target, dependent: :destroy, inverse_of: :target
  has_many :interests, as: :target, dependent: :destroy, inverse_of: :target
  has_many :observations
  has_many :projects
  has_many :project_aliases, as: :target, dependent: :destroy
  has_many :species_lists
  has_many :herbaria     # should be at most one, but nothing preventing more
  has_many :users        # via profile location

  acts_as_versioned(
    if_changed: %w[
      name
      north
      south
      west
      east
      high
      low
      notes
      box_area
      center_lat
      center_lng
    ]
  )
  non_versioned_columns.push(
    "created_at",
    "updated_at",
    "num_views",
    "last_view",
    "ok_for_export",
    "rss_log_id",
    "description_id",
    "locked",
    "hidden"
  )

  before_save :calculate_box_area_and_center
  before_update :update_observation_cache
  after_update :notify_users

  SEARCHABLE_FIELDS = [
    :name, :notes
  ].freeze

  # Automatically log standard events.  Merge will already log the destruction
  # as a merge and orphan the log.
  self.autolog_events = [:created!, :updated!, :destroyed]

  # Callback whenever new version is created.
  versioned_class.before_save do |ver|
    ver.user_id = User.current_id || User.admin_id
    if (ver.version != 1) &&
       Location::Version.where(
         location_id: ver.location_id, user_id: ver.user_id
       ).none?
      UserStats.update_contribution(:add, :location_versions)
    end
  end

  # On save, calculate bounding box area for the `box_area` column, plus the
  # `center_lat` and `center_lng` values. If box_area is below a threshold, also
  # copy the values to the observation `location_lat` `location_lng` columns, or
  # null the obs values if not. This callback can handle API updates.
  def calculate_box_area_and_center
    return unless north_changed? || east_changed? ||
                  south_changed? || west_changed?

    self.box_area = calculate_area
    self.center_lat = calculate_lat
    self.center_lng = calculate_lng
    update_observation_center_columns
  end

  # Now that the box_area and center columns are set on this location, cache or
  # update the center columns of this location's observations.
  def update_observation_center_columns
    if box_area <= MO.obs_location_max_area
      observations.update_all(location_lat: center_lat,
                              location_lng: center_lng)
    else
      observations.update_all(location_lat: nil, location_lng: nil)
    end
  end

  # Can populate columns after migration, or be run as part of a recurring job.
  def self.update_box_area_and_center_columns
    # update the locations
    loc_updated = update_all(update_center_and_area_sql)
    # give center points to associated observations in batches by location_id
    obs_centered = Observation.
                   in_box_of_max_area.group(:location_id).update_all(
                     location_lat: Location[:center_lat],
                     location_lng: Location[:center_lng]
                   )
    # null center points where area is above the threshold
    obs_center_nulled = Observation.
                        in_box_gt_max_area.group(:location_id).update_all(
                          location_lat: nil, location_lng: nil
                        )
    # Return counts
    [loc_updated, obs_centered, obs_center_nulled]
  end

  # Let attached observations update their cache if these fields changed.
  # Also touch updated_at to expire obs fragment caches
  def update_observation_cache
    return unless name_changed?

    Observation.where(location_id: id).update_all(
      { where: name, updated_at: Time.zone.now }
    )
  end

  ##############################################################################
  #
  #  :section: Lat/Long Stuff
  #
  ##############################################################################

  include Mappable::BoxMethods

  LXXXITUDE_REGEX = /^\s*
       (-?\d+(?:\.\d+)?) \s* (?:°|°|o|d|deg|,\s)? \s*
    (?: (?<![\d.]) (\d+(?:\.\d+)?) \s* (?:'|‘|’|′|′|m|min)? \s* )?
    (?: (?<![\d.]) (\d+(?:\.\d+)?) \s* (?:"|“|”|″|″|s|sec)? \s* )?
    ([NSEW]?)
  \s*$/x

  ALTITUDE_REGEX = /^\s*
    (-?\d+(?:.\d+)?) \s* (m\.?|ft\.?|['‘’′]*)
  \s*$/x

  # Shared logic between latitude and longitude
  def self.parse_lxxxitude(value, direction1, direction2, max_degrees)
    result = nil
    match = value.to_s.match(LXXXITUDE_REGEX)
    if match && (match[4].blank? || [direction1, direction2].member?(match[4]))
      val = if match[1].to_f.positive?
              match[1].to_f + match[2].to_f / 60 + match[3].to_f / 3600
            else
              match[1].to_f - match[2].to_f / 60 - match[3].to_f / 3600
            end
      val = -val if match[4] == direction2
      result = val.round(4) if val.between?(-max_degrees, max_degrees)
    end
    result
  end

  # Convert latitude string to standard decimal form with 4 places of precision.
  # Returns nil if invalid.
  def self.parse_latitude(lat)
    parse_lxxxitude(lat, "N", "S", 90)
  end

  # Convert longitude string to standard decimal form w/4 places of precision.
  # Returns nil if invalid.
  def self.parse_longitude(long)
    parse_lxxxitude(long, "E", "W", 180)
  end

  # Check if a string contains a valid altitude, parse it, and convert it
  # to an integral number of meters.
  # Returns nil if invalid.
  def self.parse_altitude(alt)
    result = nil
    match = alt.to_s.match(ALTITUDE_REGEX)
    if match && alt.to_s.match(/ft|'/)
      result = (match[1].to_f * 0.3048).round
    elsif match
      result = match[1].to_f.round
    end
    result
  end

  # Useful if invalid lat/longs cause crash, e.g., in mapping code.
  # New: Ensure box has nonzero size or make_editable_map fails.
  def force_valid_lat_lngs!
    self.north = Location.parse_latitude(north) || 45
    self.south = Location.parse_latitude(south) || -45
    self.east = Location.parse_longitude(east) || 90
    self.west = Location.parse_longitude(west) || -90
    return if north > south

    center_lat = (north + south) / 2
    center_lon = (east + west) / 2
    self.north = center_lat + 0.0001
    self.south = center_lat - 0.0001
    self.east = center_lon + 0.0001
    self.west = center_lon - 0.0001
  end

  def found_here?(obs)
    return true if obs.location == self
    return contains?(obs.lat, obs.lng) if obs.lat && obs.lng

    loc = obs.location
    return false unless loc

    # contains? is now a method of Mappable::BoxMethods
    contains?(loc.north, loc.west) && contains?(loc.south, loc.east)
  end

  # Returns a hash representing the location's bounding box
  def bounding_box
    attributes.symbolize_keys.slice(:north, :south, :west, :east)
  end

  ##############################################################################
  #
  #  :section: Name Stuff
  #
  ##############################################################################

  # Array of strings that mean "unknown" in the local language:
  #
  #   "unknown", "earth", "world", etc.
  #
  def self.names_for_unknown
    @@names_for_unknown ||= official_unknown
    (@@names_for_unknown + :unknown_locations.l.split(/, */)).uniq
  end

  def self.official_unknown
    # yikes! need to make sure we always include the English words
    # for "unknown", even when viewing the site in another language
    Language.official.translation_strings.find_by(tag: "unknown_locations").
      text.split(/, */)
  rescue StandardError
    []
  end

  # Get an instance of the Location whose name means "unknown".
  def self.unknown
    raise("There is no \"unknown_location_name\" configured!") if
      MO.unknown_location_name.blank?

    Location.find_by(name: MO.unknown_location_name)
  end

  # Is this one of the names we recognize for the "unknown" location?
  def self.is_unknown?(name)
    name = name.to_s.strip_squeeze.downcase
    names_for_unknown.each do |unknown_name|
      return true if name == unknown_name.downcase
    end
    false
  end

  # Abbreviated description of the location for shorter query titles.
  # Just the location without locality, region, country
  def title_display_name
    name.split(", ").first
  end

  def display_name
    User.current_location_format == "scientific" ? scientific_name : name
  end

  def display_name=(val)
    if User.current_location_format == "scientific"
      self.name = Location.reverse_name(val)
      self.scientific_name = val
    else
      self.name = val
      self.scientific_name = Location.reverse_name(val)
    end
  end

  # Plain text version of +display_name+.
  def text_name
    display_name.t.html_to_ascii
  end

  # Alias for +display_name+ for compatibility with Name and other models.
  def format_name
    display_name
  end

  def textile_name
    display_name
  end

  # Same as +text_name+ but with id tacked on.
  def unique_text_name
    text_name + " (#{id || "?"})"
  end

  # Same as +format_name+ but with id tacked on.
  def unique_format_name
    format_name + " (#{id || "?"})"
  end

  # Info to include about each location in merge requests.
  def merge_info
    num_obs = observations.count
    "#{:LOCATION.l} ##{id}: #{name} [o=#{num_obs}]"
  end

  # Strip out special characters, punctuation, and small words from a name.
  # This is supposed to make it easier to search for a name if you don't know
  # how it is worded.  I'm not so sure anymore...
  #
  #   pattern = Location.clean_name(pattern)
  #   locs = Location.find_all(
  #     :conditions => ['name LIKE "%?%"', pattern]
  #   )
  #
  def self.clean_name(str, leave_stars = false)
    str = str.to_ascii
    if leave_stars
      str.gsub!(/[^\w*]+/, " ")
      str.gsub!(/ +\*/, "*")
      str.gsub!(/\* +/, "*")
    else
      str.gsub!(/\W+/, " ")
    end
    str.strip_squeeze.downcase
  end

  # Cleans up a place_name (per Observation) and
  # applies the current user's current_location_format
  def self.normalize_place_name(place_name)
    place_name = place_name&.strip_squeeze
    if User.current_location_format == "scientific"
      reverse_name(place_name)
    else
      place_name
    end
  end

  # Returns any existing location that matches place_name
  def self.place_name_to_location(place_name)
    find_by_name(normalize_place_name(place_name))
  end

  # Takes a location string splits on commas, reverses the order,
  # and joins it back together
  # E.g., "New York, USA" => "USA, New York"
  # Used to support the "scientific" location format.
  def self.reverse_name(name)
    name&.split(/,\s*/)&.reverse&.join(", ")
  end

  # Reverse a name string which might contain "*" wildcards.  Note that the
  # "*" swaps front to back on some words but not all.  Just the ones at the
  # beginning and end of the string.
  #
  #   "*California, USA"          → "USA, California*"
  #   "*, Smokies, * Co., *, USA" → "USA, *, * Co., Smokies, *"
  #
  def self.reverse_name_with_wildcards(name)
    name2 = name.to_s.dup
    left  = "*" if name2.sub!(/^\*/, "")
    right = "*" if name2.sub!(/\*$/, "")
    "#{right}#{reverse_name(name2)}#{left}"
  end

  # Reverse given name if required in order to make country last.
  def self.reverse_name_if_necessary(name)
    last_part = name.split(/,\s*/).last
    understood_country?(last_part) ? name : reverse_name(name)
  end

  # Looks for a matching location using either location order just to be sure
  def self.find_by_name_or_reverse_name(name)
    Location.where(name: name).
      or(Location.where(scientific_name: name)).first
  end

  def self.user_format(user, name)
    if user && (user.location_format == "scientific")
      Location.reverse_name(name)
    else
      name
    end
  end

  def self.load_param_hash(file)
    File.open(file, "r:utf-8") do |fh|
      YAML.load(fh)
    end
  end

  UNDERSTOOD_CONTINENTS = load_param_hash(MO.location_continents_file)
  UNDERSTOOD_COUNTRIES = load_param_hash(MO.location_countries_file)
  UNDERSTOOD_STATES    = load_param_hash(MO.location_states_file)
  OK_PREFIXES          = load_param_hash(MO.location_prefixes_file)
  BAD_TERMS            = load_param_hash(MO.location_bad_terms_file)
  BAD_CHARS            = "({[;:|]})"

  def self.understood_continents
    UNDERSTOOD_CONTINENTS
  end

  def self.understood_countries
    UNDERSTOOD_COUNTRIES
  end

  def self.understood_states(country)
    UNDERSTOOD_STATES[country]
  end

  # Returns a member of understood_places if the candidate is either a member
  # or if the candidate stripped of all the OK_PREFIXES is a member.  Otherwise
  # it returns nil.
  def self.understood_with_prefixes(candidate, understood_places)
    return candidate if understood_places.member?(candidate)

    tokens = candidate.to_s.split
    count = 0
    tokens.each do |s|
      if OK_PREFIXES.member?(s)
        count += 1
      else
        trimmed = tokens[count..].join(" ")
        return trimmed if understood_places.member?(trimmed)
      end
    end
    nil
  end

  def self.has_known_states?(a_country)
    UNDERSTOOD_STATES.member?(a_country)
  end

  def self.understood_state?(candidate, a_country)
    understood_with_prefixes(candidate, UNDERSTOOD_STATES[a_country])
  end

  def self.understood_country?(candidate)
    understood_with_prefixes(candidate, UNDERSTOOD_COUNTRIES)
  end

  def self.understood_continent?(candidate)
    UNDERSTOOD_CONTINENTS.key?(candidate)
  end

  def self.countries_in_continent(a_continent)
    UNDERSTOOD_CONTINENTS[a_continent]
  end

  def self.countries_by_count
    CountryCounter.new.countries_by_count
  end

  def self.location_name_cache
    Rails.cache.fetch(:location_names, expires_in: 15.minutes) do
      (Location.pluck(:name) + Observation.pluck(:where) +
       SpeciesList.pluck(:where)).compact.uniq
    end
  end

  # Check if a given place name (postal order) already exists,
  # defined as a Location or undefined as a saved `where` string.
  def self.location_name_exists?(name)
    return false unless name

    location_name_cache.member?(name)
  end

  # Decide if the given name is dubious for any reason
  def self.dubious_name?(name, provide_reasons = false, check_db = true)
    reasons = []
    unless check_db && location_name_exists?(name)
      reasons += check_for_empty_name(name)
      reasons += check_for_dubious_commas(name)
      reasons += check_for_bad_country_or_state(name)
      reasons += check_for_bad_terms(name)
      reasons += check_for_bad_chars(name)
    end
    provide_reasons ? reasons : reasons.any?
  end

  def self.check_for_empty_name(name)
    return [] if name.present?

    [:location_dubious_empty.l]
  end

  def self.check_for_dubious_commas(name)
    return [] unless comma_test(name)

    [:location_dubious_commas.l]
  end

  def self.check_for_bad_country_or_state(name)
    reasons = []
    return [] if name.blank?

    this_country = country(name)
    this_state = state(name)
    real_country = understood_country?(this_country)
    if real_country.nil?
      reasons << :location_dubious_unknown_country.t(country: this_country)
    end
    if real_country && has_known_states?(real_country)
      if this_state
        if understood_state?(this_state, real_country).nil?
          reasons << :location_dubious_unknown_state.t(country: real_country,
                                                       state: this_state)
        end
      elsif this_country != real_country
        # Note that we accept things like "Western Mexico" as a valid country
        # modified by "Western".  However, in the case of Australia, this could
        # be ambiguous because there is also a state "Western Australia".
        # But note that Mexico has a state also called Mexico.  We want to
        # complain if the user enters "Western Australia" bare because they
        # may have just forgotten to include the country.  But we do not want
        # to complain if the user enters "Mexico" bare because that is fine.
        # If the user also entered a state, say "Perth, Western Australia",
        # then it will complain above because "Perth" is not a valid state of
        # Australia.  The use case that prompted this subtle change in logic
        # was that it was impossible to enter *any* location in Mexico because
        # Mexico was an ambiguous state/country!  Now this code only applies
        # to a bare country which may be ambiguous.
        if understood_state?(this_country, real_country)
          reasons << :location_dubious_ambiguous_country.
                     t(country: this_country)
        end
      end
    elsif this_state && understood_country?(this_state)
      reasons << :location_dubious_redundant_state.t(country: real_country,
                                                     state: this_state)
    end
    reasons
  end

  def self.check_for_bad_terms(name)
    reasons = []
    return [] if name.blank?

    BAD_TERMS.each_key do |key|
      next unless name.index(key)

      reasons << :location_dubious_bad_term.t(bad: key, good: BAD_TERMS[key])
    end
    reasons
  end

  def self.check_for_bad_chars(name)
    reasons = []
    return [] if name.blank?

    # For some reason BAD_CHARS.chars.each doesn't work
    count = 0
    while (c = BAD_CHARS[count])
      reasons << :location_dubious_bad_char.t(char: c) if name.index(c)
      count += 1
    end
    reasons
  end

  def self.comma_test(name)
    return if name.blank?

    tokens = name.split(",").map(&:strip)
    tokens.delete("")
    name != tokens.join(", ")
  end

  def self.country(name)
    result = name.split(",")[-1]
    result = result.strip if result
    result
  end

  def self.state(name)
    result = name.split(",")[-2]
    result = result.strip if result
    result
  end

  def self.dubious_country?(name)
    !understood_country?(country(name))
  end

  def self.fix_country(name)
    c = country(name)
    name[0..(name.rindex(c) - 1)] + COUNTRY_FIXES[c]
  end

  def self.find_by_name_with_wildcards(str)
    find_using_wildcards("name", str)
  end

  def self.find_by_scientific_name_with_wildcards(str)
    find_using_wildcards("name", reverse_name_with_wildcards(str))
  end

  ##############################################################################
  #
  #  :section: Merging
  #
  ##############################################################################

  # Is it safe to merge this Location with another?  If any information will
  # get lost we return false.  In practice only if it has Observations.
  def mergable?
    observations.empty?
  end

  # Merge all the stuff that refers to +old_loc+ into +self+.  No changes are
  # made to +self+; +old_loc+ is destroyed; all the things that referred to
  # +old_loc+ are updated and saved.
  def merge(user, old_loc, _log = true)
    return if old_loc == self

    # Move observations over first.
    old_loc.observations.each do |obs|
      obs.location = self
      obs.save
    end

    # change object.location without verification
    [Herbarium, Project, SpeciesList, User].each do |klass|
      klass.where(location_id: old_loc.id).find_each do |obj|
        obj.update_attribute(:location, self)
      end
    end

    # Move over any interest in the old name.
    [Interest, ProjectAlias].each do |klass|
      klass.where(target_type: "Location",
                  target_id: old_loc.id).find_each do |obj|
        obj.target = self
        obj.save
      end
    end

    add_note(explain_merge(old_loc))

    update_location_descriptions(old_loc)

    # Log the action.
    old_loc.rss_log&.orphan(user, old_loc.name, :log_location_merged,
                            this: old_loc.name, that: name)
    old_loc.rss_log = nil

    # Destroy past versions.
    editors = []
    old_loc.versions.each do |ver|
      editors << ver.user_id
      ver.destroy
    end

    # Update contributions for editors.
    editors.delete(old_loc.user_id)
    editors.uniq.each do |user_id|
      UserStats.update_contribution(:del, :location_versions, user_id)
    end

    # Finally destroy the location.
    old_loc.destroy
  end

  private

  def explain_merge(old_loc)
    # Intentionally not translated
    <<~EXPLANATION.tr("\n", " ")
      [admin - #{Time.zone.now}]: Merged with #{old_loc.name}
      (was Location ##{old_loc.id}):
      North: #{old_loc.north}, South: #{old_loc.south},
      West: #{old_loc.west}, East: #{old_loc.east}
    EXPLANATION
  end

  def update_location_descriptions(old_loc)
    # Merge the two "main" descriptions if it can.
    if description && old_loc.description &&
       (description.source_type == :public) &&
       (old_loc.description.source_type == :public)
      description.merge(old_loc.description)
    end

    # If this one doesn't have a primary description and the other does,
    # then make it this one's.
    if !description && old_loc.description
      self.description = old_loc.description
    end

    # Move over any remaining descriptions.
    old_loc.descriptions.each do |desc|
      desc.location_id = id
      desc.save
    end
  end

  public

  ##############################################################################
  #
  #  :section: Callbacks
  #
  ##############################################################################

  # This is called after saving potential changes to a Location.  It will
  # determine if the changes are important enough to notify people, and do so.
  def notify_users
    return unless saved_version_changes?

    sender = User.current
    recipients = []

    # Tell admins of the change.
    descriptions.map(&:admins).each do |user_list|
      user_list.each do |user|
        recipients.push(user) if user.email_locations_admin
      end
    end

    # Tell authors of the change.
    descriptions.map(&:authors).each do |user_list|
      user_list.each do |user|
        recipients.push(user) if user.email_locations_author
      end
    end

    # Tell editors of the change.
    descriptions.map(&:editors).each do |user_list|
      user_list.each do |user|
        recipients.push(user) if user.email_locations_editor
      end
    end

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
    (recipients.uniq - [sender]).each do |recipient|
      QueuedEmail::LocationChange.create_email(sender, recipient, self)
    end
  end

  ##############################################################################

  protected

  validate :check_requirements
  def check_requirements
    check_hidden

    if !north || (north > 90)
      errors.add(:north, :validate_location_north_too_high.t)
    end
    if !south || (south < -90)
      errors.add(:south, :validate_location_south_too_low.t)
    end
    if north && south && (north < south)
      errors.add(:north, :validate_location_north_less_than_south.t)
    end

    if !east || (east < -180) || (east > 180)
      errors.add(:east, :validate_location_east_out_of_bounds.t)
    end
    if !west || (west < -180) || (west > 180)
      errors.add(:west, :validate_location_west_out_of_bounds.t)
    end

    if high && low && (high < low)
      errors.add(:high, :validate_location_high_less_than_low.t)
    end

    if !user && !User.current
      errors.add(:user, :validate_location_user_missing.t)
    end

    if name.to_s.size > 1024
      errors.add(:name, :validate_location_name_too_long.t)
    elsif name.empty?
      errors.add(:name, :validate_missing.t(field: :name))
    end
  end

  def check_hidden
    return unless hidden

    self.north = north.ceil(1)
    self.south = south.floor(1)
    self.east = east.ceil(1)
    self.west = west.floor(1)
  end
end
