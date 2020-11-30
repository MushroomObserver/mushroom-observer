# frozen_string_literal: true

#
#  = Location Model
#
#  Model to describe a location.  Locations are rectangular regions, not
#  points, with an associated free-form description.
#
#  == Version
#
#  Changes are kept in the "locations_versions" table using
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
#
#  ('V' indicates that this attribute is versioned in past_locations table.)
#
#  == Class methods
#
#  primer::             List of User's latest Locations to prime auto-completer.
#  clean_name::         Clean a name before doing searches on it.
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
#
class Location < AbstractModel
  require "acts_as_versioned"

  belongs_to :description, class_name: "LocationDescription" # (main one)
  belongs_to :rss_log
  belongs_to :user

  has_many :descriptions, -> { order "num_views DESC" },
           class_name: "LocationDescription"
  has_many :comments,  as: :target, dependent: :destroy
  has_many :interests, as: :target, dependent: :destroy
  has_many :observations
  has_many :species_lists
  has_many :herbaria     # should be at most one, but nothing preventing more
  has_many :users        # via profile location

  acts_as_versioned(
    table_name: "locations_versions",
    if_changed: %w[
      name
      north
      south
      west
      east
      high
      low
      notes
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
    "locked"
  )

  before_update :update_observation_cache
  after_update :notify_users

  # Automatically log standard events.
  self.autolog_events = [:created!, :updated!]

  # Callback whenever new version is created.
  versioned_class.before_save do |ver|
    ver.user_id = User.current_id || User.admin_id
    if (ver.version != 1) &&
       Location.connection.select_value(%(
         SELECT COUNT(*) FROM locations_versions
         WHERE location_id = #{ver.location_id} AND user_id = #{ver.user_id}
       )).to_s == "0"
      SiteData.update_contribution(:add, :locations_versions)
    end
  end

  # Let attached observations update their cache if these fields changed.
  def update_observation_cache
    Observation.update_cache("location", "where", id, name) if name_changed?
  end

  ##############################################################################
  #
  #  :section: Lat/Long Stuff
  #
  ##############################################################################

  include BoxMethods

  LXXXITUDE_REGEX = /^\s*
       (-?\d+(?:\.\d+)?) \s* (?:°|°|o|d|deg|,\s)? \s*
    (?: (?<![\d\.]) (\d+(?:\.\d+)?) \s* (?:'|‘|’|′|′|m|min)? \s* )?
    (?: (?<![\d\.]) (\d+(?:\.\d+)?) \s* (?:"|“|”|″|″|s|sec)? \s* )?
    ([NSEW]?)
  \s*$/x.freeze

  ALTITUDE_REGEX = /^\s*
    (-?\d+(?:.\d+)?) \s* (m\.?|ft\.?|['‘’′′]*)
  \s*$/x.freeze

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
      result = val.round(4) if val >= -max_degrees && val <= max_degrees
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
  def force_valid_lat_longs!
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
    Language.official.translation_strings.find_by_tag("unknown_locations").
      text.split(/, */)
  rescue StandardError
    []
  end

  # Get an instance of the Name that means "unknown".
  def self.unknown
    names_for_unknown.each do |name|
      # location = Location.find(:first, :conditions => ['name like ?', name])
      location = Location.where("name LIKE ?", name).first
      return location if location
    end
    raise("There is no \"unknown\" location!")
  end

  # Is this one of the names we recognize for the "unknown" location?
  def self.is_unknown?(name)
    name = name.to_s.strip_squeeze.downcase
    names_for_unknown.each do |unknown_name|
      return true if name == unknown_name.downcase
    end
    false
  end

  def display_name
    User.current_location_format == :scientific ? scientific_name : name
  end

  def display_name=(val)
    if User.current_location_format == :scientific
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
      str.gsub!(/[^\w\*]+/, " ")
      str.gsub!(/ +\*/, "*")
      str.gsub!(/\* +/, "*")
    else
      str.gsub!(/\W+/, " ")
    end
    str.strip_squeeze.downcase
  end

  # Look at the most recent Observation's the current User has posted.  Return
  # a list of the last 100 place names used in those Observation's (either
  # Location names or "where" strings).  This list is used to prime Location
  # auto-completers.
  #
  def self.primer
    # Temporarily disable. It rarely takes autocomplete long even on my horrible
    # internet connection. And the primer can -- at least briefly -- have names
    # that have been merged or changed.  That may be confusing some users. Let's
    # try it without for a while to see if anyone complains.
    # where = ""
    # where = "WHERE observations.user_id = #{User.current_id}" if User.current
    # result = connection.select_values(%(
    #   SELECT DISTINCT IF(observations.location_id > 0,
    #                      locations.name,
    #                      observations.where) AS x
    #   FROM observations
    #   LEFT OUTER JOIN locations ON locations.id = observations.location_id
    #   #{where}
    #   ORDER BY observations.updated_at DESC
    #   LIMIT 100
    # )).sort
    # if User.current_location_format == :scientific
    #   result.map! { |n| Location.reverse_name(n) }
    # end
    # result
    []
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
    find_by_name(name) ||
      find_by_scientific_name(name)
  end

  def self.user_name(user, name)
    if user && (user.location_format == :scientific)
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
        trimmed = tokens[count..-1].join(" ")
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

  @@location_cache = nil

  # Check if a given name (postal order) already exists as a defined
  # or undefined location.
  def self.location_exists(name)
    return false unless name

    @@location_cache ||= (
      Location.connection.select_values(%(
        SELECT name FROM locations
      )) +
      Location.connection.select_values(%(
        SELECT `where` FROM `observations`
        WHERE `where` is not NULL
      )) +
      Location.connection.select_values(%(
        SELECT `where` FROM `species_lists`
        WHERE `where` is not NULL
      ))
    ).uniq
    @@location_cache.member?(name)
  end

  # Decide if the given name is dubious for any reason
  def self.dubious_name?(name, provide_reasons = false, check_db = true)
    reasons = []
    unless check_db && location_exists(name)
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

  # Return some locations that are close to the given name.
  def self.suggestions(str)
    locations_close_to(str) +
      locations_with_additional_word(str) +
      locations_missing_a_word(str)
  end

  private

  def self.locations_close_to(str)
    min = str.length - 5
    max = str.length + 5
    Location.where("LENGTH(name) BETWEEN ? AND ?", min, max).to_a.
             sort_by { |l| -str.percent_match(l.name) }[0..4]
  end

  def self.locations_with_additional_word(str)
    words1 = []
    words2 = str.split(", ")
    num_words = words2.length
    return [] if num_words < 3

    conditions = (0..num_words).map do
      pattern = (words1 + ["%"] + words2).join(", ")
      words1.push(words2.shift)
      "name LIKE #{connection.quote(pattern)}"
    end.join(" OR ")
    Location.where(conditions).to_a
  end

  def self.locations_missing_a_word(str)
    words1 = []
    words2 = str.split(", ")
    num_words = words2.length
    return [] if num_words < 4

    names = (1..num_words).map do
      omit = words2.shift
      name = (words1 + words2).join(", ")
      words1.push(omit)
      name
    end
    Location.where(name: names)
  end

  public

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
  def merge(old_loc, _log = true)
    return if old_loc == self

    # Move observations over first.
    old_loc.observations.each do |obs|
      obs.location = self
      obs.save
    end

    # Move species lists over.
    SpeciesList.where(location_id: old_loc.id).find_each do |spl|
      spl.update_attribute(:location, self)
    end

    # Update any users who call this location their primary location.
    User.where(location_id: old_loc.id).find_each do |user|
      user.update_attribute(:location, self)
    end

    # Move over any interest in the old name.
    Interest.where(target_type: "Location",
                   target_id: old_loc.id).find_each do |int|
      int.target = self
      int.save
    end

    # Add note to explain the merge
    # Intentionally not translated
    add_note("[admin - #{Time.zone.now}]: Merged with #{old_loc.name}: "\
             "North: #{old_loc.north}, South: #{old_loc.south}, "\
             "West: #{old_loc.west}, East: #{old_loc.east}")

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

    # Log the action.
    old_loc.rss_log&.orphan(old_loc.name, :log_location_merged,
                            this: old_loc.name, that: name)

    # Destroy past versions.
    editors = []
    old_loc.versions.each do |ver|
      editors << ver.user_id
      ver.destroy
    end

    # Update contributions for editors.
    editors.delete(old_loc.user_id)
    editors.uniq.each do |user_id|
      SiteData.update_contribution(:del, :locations_versions, user_id)
    end

    # Finally destroy the location.
    old_loc.destroy
  end

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

    # Tell masochists who want to know about all location changes.
    User.where(email_locations_all: true).find_each do |user|
      recipients.push(user)
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

    # Send notification to all except the person who triggered the change.
    (recipients.uniq - [sender]).each do |recipient|
      QueuedEmail::LocationChange.create_email(sender, recipient, self)
    end
  end

  ##############################################################################

  protected

  validate :check_requirements
  def check_requirements # :nodoc:
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
end
