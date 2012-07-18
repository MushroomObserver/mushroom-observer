# encoding: utf-8
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
#  id::            (-) Locally unique numerical id, starting at 1.
#  sync_id::       (-) Globally unique alphanumeric id, used to sync with remote servers.
#  created::       (-) Date/time it was first created.
#  modified::      (V) Date/time it was last modified.
#  user::          (V) User that created it.
#  version::       (V) Version number.
#  ---
#  name::          (V) Name, e.g.: "Lacy Park, Los Angeles Co., California, USA"
#  north::         (V) North edge in degrees north, e.g. 37.8233
#  south::         (V) South edge in degrees north, e.g. 37.8035
#  east::          (V) East edge in degrees east, e.g. -122.173
#  west::          (V) West edge in degrees east, e.g. -122.204
#  high::          (V) Maximum elevation in meters, e.g. 100
#  low::           (V) Minimum elevation in meters, e.g. 0
#  notes::         (V) Arbitrary extra notes supplied by User.
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

class Location < AbstractModel
  belongs_to :description, :class_name => 'LocationDescription' # (main one)
  belongs_to :rss_log
  belongs_to :user

  has_many :descriptions, :class_name => 'LocationDescription', :order => 'num_views DESC'
  has_many :comments,  :as => :target, :dependent => :destroy
  has_many :interests, :as => :target, :dependent => :destroy
  has_many :observations

  acts_as_versioned(
    :table_name => 'locations_versions',
    :if_changed => [
      'name',
      'north',
      'south',
      'west',
      'east',
      'high',
      'low',
      'notes'
  ])
  non_versioned_columns.push(
    'sync_id',
    'created',
    'num_views',
    'last_view',
    'ok_for_export',
    'rss_log_id',
    'description_id'
  )

#  before_save  :set_search_name
  after_update :notify_users

  # Automatically log standard events.
  self.autolog_events = [:created!, :updated!]

  # Callback whenever new version is created.
  versioned_class.before_save do |ver|
    ver.user_id = User.current_id
    if (ver.version != 1) and
       Location.connection.select_value(%(
         SELECT COUNT(*) FROM locations_versions
         WHERE location_id = #{ver.location_id} AND user_id = #{ver.user_id}
       )).to_s == '0'
      SiteData.update_contribution(:add, :locations_versions)
    end
  end

  ##############################################################################
  #
  #  :section: Lat/Long Stuff
  #
  ##############################################################################

  include BoxMethods

  LXXXITUDE_REGEX = /^\s*
       (-?\d+(?:\.\d+)?) (?:°|°|o|d|deg)?     \s*
    (?: (?<![\d\.]) (\d+(?:\.\d+)?) (?:'|‘|’|′|′|m|min)? \s* )?
    (?: (?<![\d\.]) (\d+(?:\.\d+)?) (?:"|“|”|″|″|s|sec)? \s* )?
    ([NSEW]?)
  \s*$/x

  ALTITUDE_REGEX = /^\s*
    (-?\d+(?:.\d+)?) \s* (m\.?|ft\.?|['‘’′′]*)
  \s*$/x

  # Shared logic between latitude and longitude
  def self.parse_lxxxitude(value, direction1, direction2, max_degrees)
    result = nil
    match = value.to_s.match(LXXXITUDE_REGEX)
    if match and (match[4].blank? or [direction1, direction2].member?(match[4]))
      val = match[1].to_f + match[2].to_f/60 + match[3].to_f/3600
      val = -val if match[4] == direction2
      if val >= -max_degrees and val <= max_degrees
        result = val.round(4)
      end
    end
    return result
  end

  # Convert latitude string to standard decimal form with 4 places of precision.
  # Returns nil if invalid.
  def self.parse_latitude(lat)
    return parse_lxxxitude(lat, 'N', 'S', 90)
  end

  # Convert longitude string to standard decimal form with 4 places of precision.
  # Returns nil if invalid.
  def self.parse_longitude(long)
    return parse_lxxxitude(long, 'E', 'W', 180)
  end

  # Check if a string contains a valid altitude, parse it, and convert it
  # to an integral number of meters.
  # Returns nil if invalid.
  def self.parse_altitude(alt)
    result = nil
    match = alt.to_s.match(ALTITUDE_REGEX)
    if match and alt.to_s.match(/ft|'/)
      result = (match[1].to_f * 0.3048).round
    elsif match
      result = (match[1].to_f).round
    end
    return result
  end

  # Useful if invalid lat/longs cause crash, e.g., in mapping code.
  def force_valid_lat_longs!
    self.north = Location.parse_latitude(north) || 45
    self.south = Location.parse_latitude(south) || -45
    self.east = Location.parse_longitude(east) || 90
    self.west = Location.parse_longitude(west) || -90
    self.north, self.south = south, north if north < south
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
    @@names_for_unknown ||= begin
      # yikes! need to make sure we always include the English words for "unknown",
      # even when viewing the site in another language
      Language.official.translation_strings.find_by_tag('unknown_locations').text.split(/, */)
    rescue
      []
    end
    (@@names_for_unknown + :unknown_locations.l.split(/, */)).uniq
  end

  # Get an instance of the Name that means "unknown".
  def self.unknown
    for name in names_for_unknown
      location = Location.find(:first, :conditions => ['name like ?', name])
      return location if location
    end
    raise "There is no \"unknown\" location!"
  end

  # Is this one of the names we recognize for the "unknown" location?
  def self.is_unknown?(name)
    name = name.to_s.strip_squeeze.downcase
    for unknown_name in names_for_unknown
      return true if name == unknown_name.downcase
    end
    return false
  end

  def display_name()
    if User.current_location_format == :scientific
      self.scientific_name
    else
      self.name
    end
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
    self.display_name.t.html_to_ascii
  end

  # Alias for +display_name+ for compatibility with Name and other models.
  def format_name
    self.display_name
  end

  # Same as +text_name+ but with id tacked on.
  def unique_text_name
    text_name + " (#{id || '?'})"
  end

  # Same as +format_name+ but with id tacked on.
  def unique_format_name
    format_name + " (#{id || '?'})"
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
  def self.clean_name(str, leave_stars=false)
    str = str.to_ascii
    if leave_stars
      str.gsub!(/[^\w\*]+/, ' ')
      str.gsub!(/ +\*/, '*')
      str.gsub!(/\* +/, '*')
    else
      str.gsub!(/\W+/, ' ')
    end
    return str.strip_squeeze.downcase
  end

  # Look at the most recent Observation's the current User has posted.  Return
  # a list of the last 100 place names used in those Observation's (either
  # Location names or "where" strings).  This list is used to prime Location
  # auto-completers.
  #
  def self.primer
    where = ''
    if User.current
      where = "WHERE observations.user_id = #{User.current_id}"
    end
    result = self.connection.select_values(%(
      SELECT DISTINCT IF(observations.location_id > 0, locations.name, observations.where) AS x
      FROM observations
      LEFT OUTER JOIN locations ON locations.id = observations.location_id
      #{where}
      ORDER BY observations.modified DESC
      LIMIT 100
    )).sort
    if User.current_location_format == :scientific
      result.map! {|n| Location.reverse_name(n)}
    end
    result
  end

  # Takes a location string splits on commas, reverses the order, and joins it back together
  # E.g., "New York, USA" => "USA, New York"
  # Used to support the "scientific" location format.
  def self.reverse_name(name)
    name.split(/,\s*/).reverse.join(', ') if name
  end

  # Looks for a matching location using either location order just to be sure
  def self.find_by_name_or_reverse_name(name)
    find_by_name(name) ||
    find_by_scientific_name(name)
  end

  def self.user_name(user, name)
    if user and (user.location_format == :scientific)
      Location.reverse_name(name)
    else
      name
    end
  end

  def self.load_param_hash(file)
    File.open(file, 'r:utf-8') do |fh|
      YAML::load(fh)
    end
  end

  UNDERSTOOD_COUNTRIES = load_param_hash(LOCATION_COUNTRIES_FILE)
  UNDERSTOOD_STATES    = load_param_hash(LOCATION_STATES_FILE)
  OK_PREFIXES          = load_param_hash(LOCATION_PREFIXES_FILE)
  BAD_TERMS            = load_param_hash(LOCATION_BAD_TERMS_FILE)
  BAD_CHARS            = "({[;:|]})"

  # Returns a member of understood_places if the candidate is either a member or
  # if the candidate stripped of all the OK_PREFIXES is a member.  Otherwise
  # it returns nil.
  def self.understood_with_prefixes(candidate, understood_places)
    result = nil
    if understood_places.member?(candidate)
      result = candidate
    else
      tokens = candidate.split
      count = 0
      for s in tokens
        if OK_PREFIXES.member?(s)
          count += 1
        else
          trimmed = tokens[count..-1].join(' ')
          if understood_places.member?(trimmed)
            result = trimmed
          end
          break
        end
      end
    end
    result
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

  @@location_cache = nil

  # Check if a given name (postal order) already exists as a defined
  # or undefined location.
  def self.location_exists(name)
    if name
      if @@location_cache.nil?
        @@location_cache = (
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
      end
      @@location_cache.member?(name)
    else
      false
    end
  end

  def self.comma_test(name)
    tokens = name.split(',').map { |x| x.strip() }
    tokens.delete("")
    return name != tokens.join(', ')
  end

  # Decide if the given name is dubious for any reason
  def self.dubious_name?(name, provide_reasons=false, check_db=true)
    reasons = []
    if not (check_db and location_exists(name))
      if name == ''
        return true if !provide_reasons
        return [:location_dubious_empty.l]
      end
      if Location.comma_test(name)
        return true if !provide_reasons
	      reasons.push(:location_dubious_commas.l)
      end
      if name.index('Forest,').nil? and name.index('Park,').nil? and name.index('near ').nil? and has_dubious_county?(name)
        return true if !provide_reasons
        reasons.push(:location_dubious_redundant_county.l)
      end
      a_country = understood_country?(country(name))
      if a_country.nil?
        return true if !provide_reasons
        reasons.push(:location_dubious_unknown_country.t(:country => country(name)))
      end
      if has_known_states?(a_country)
        if understood_state?(country(name), a_country) # "Western Australia" for example
          return true if !provide_reasons
          reasons.push(:location_dubious_ambiguous_country.t(:country => a_country))
        end
        a_state = state(name)
        if a_state and understood_state?(a_state, a_country).nil?
	        return true if !provide_reasons
          reasons.push(:location_dubious_unknown_state.t(:country => a_country, :state => a_state))
        end
      else
        a_state = state(name)
        if a_state and understood_country?(a_state)
          return true if !provide_reasons
          reasons.push(:location_dubious_redundant_state.t(:country => a_country, :state => a_state))
        end
      end
      for key in BAD_TERMS.keys()
        if name.index(key)
          return true if !provide_reasons
          reasons.push(:location_dubious_bad_term.t(:bad => key, :good => BAD_TERMS[key]))
        end
      end
      count = 0
      while (c = BAD_CHARS[count]) # For some reason BAD_CHARS.chars.each doesn't work
        if name.index(c)
          return true if !provide_reasons
          reasons.push(:location_dubious_bad_char.t(:char => c))
        end
        count += 1
      end
    end
    return false if !provide_reasons
    reasons
  end

  def self.country(name)
    result = name.split(',')[-1]
    result = result.strip() if result
    result
  end

  def self.state(name)
    result = name.split(',')[-2]
    result = result.strip() if result
    result
  end

  def self.dubious_country?(name)
    not understood_country?(country(name))
  end

  def self.has_dubious_county?(name)
    tokens = name.split(", ")
    alt = [tokens[0]]
    for t in tokens[1..-1]
      alt.push(t) if " Co." != t[-4..-1]
    end
    result = alt.join(", ")
    if result == name
      nil
    else
      result
    end
  end

  def self.fix_country(name)
    c = country(name)
    new_country =
    name[0..(name.rindex(c)-1)] + COUNTRY_FIXES[c]
  end

  ##############################################################################
  #
  #  :section: Merging
  #
  ##############################################################################

  # Is it safe to merge this Location with another?  If any information will
  # get lost we return false.  In practice only if it has Observations.
  def mergable?
    observations.length == 0
  end

  # Merge all the stuff that refers to +old_loc+ into +self+.  No changes are
  # made to +self+; +old_loc+ is destroyed; all the things that referred to
  # +old_loc+ are updated and saved.
  def merge(old_loc, log = true)
    # Move observations over first.
    for obs in old_loc.observations
      obs.location = self
      obs.save
      Transaction.put_observation(
        :id           => obs,
        :set_location => self
      )
    end

    # Move species lists over.
    for spl in SpeciesList.find_all_by_location_id(old_loc.id)
      spl.update_attribute(:location, self)
      Transaction.put_species_list(
        :id           => spl,
        :set_location => self
      )
    end

    # Update any users who call this location their primary location.
    for user in User.find_all_by_location_id(old_loc.id)
      user.update_attribute(:location, self)
      Transaction.put_user(
        :id           => user,
        :set_location => self
      )
    end

    # Move over any interest in the old name.
    for int in Interest.find_all_by_target_type_and_target_id('Location',
                                                              old_loc.id)
      int.target = self
      int.save
    end

    # Add note to explain the merge
    # Intentionally not translated
    add_note("[admin - #{Time.now}]: Merged with #{old_loc.name}: North: #{old_loc.north}, South: #{old_loc.south}, West: #{old_loc.west}, East: #{old_loc.east}")

    # Merge the two "main" descriptions if it can.
    if self.description and old_loc.description and
       (self.description.source_type == :public) and
       (old_loc.description.source_type == :public)
      self.description.merge(old_loc.description)
    end

    # If this one doesn't have a primary description and the other does,
    # then make it this one's.
    if !self.description && old_loc.description
      self.description = old_loc.description
    end

    # Move over any remaining descriptions.
    for desc in old_loc.descriptions
      xargs = {
        :id           => desc,
        :set_location => self,
      }
      desc.location_id = self.id
      desc.save
      Transaction.put_location_description(xargs)
    end

    # Log the action.
    old_loc.rss_log.orphan(old_loc.name, :log_location_merged,
      :this => old_loc.name, :that => self.name) if old_loc.rss_log

    # Destroy past versions.
    editors = []
    for ver in old_loc.versions
      editors << ver.user_id
      ver.destroy
    end

    # Update contributions for editors.
    editors.delete(old_loc.user_id)
    for user_id in editors.uniq
      SiteData.update_contribution(:del, :locations_versions, user_id)
    end

    # Finally destroy the location.
    old_loc.destroy
    Transaction.delete_location(:id => old_loc)
  end

  ##############################################################################
  #
  #  :section: Callbacks
  #
  ##############################################################################

  # This is called after saving potential changes to a Location.  It will
  # determine if the changes are important enough to notify people, and do so.
  def notify_users

    # "altered?" is acts_as_versioned's equivalent to Rails's changed? method.
    # It only returns true if *important* changes have been made.
    if altered?
      sender = User.current
      recipients = []

      # Tell admins of the change.
      for user_list in descriptions.map(&:admins)
        for user in user_list
          recipients.push(user) if user.email_locations_admin
        end
      end

      # Tell authors of the change.
      for user_list in descriptions.map(&:authors)
        for user in user_list
          recipients.push(user) if user.email_locations_author
        end
      end

      # Tell editors of the change.
      for user_list in descriptions.map(&:editors)
        for user in user_list
          recipients.push(user) if user.email_locations_editor
        end
      end

      # Tell masochists who want to know about all location changes.
      for user in User.find_all_by_email_locations_all(true)
        recipients.push(user)
      end

      # Send to people who have registered interest.
      # Also remove everyone who has explicitly said they are NOT interested.
      for interest in interests
        if interest.state
          recipients.push(interest.user)
        else
          recipients.delete(interest.user)
        end
      end

      # Send notification to all except the person who triggered the change.
      for recipient in recipients.uniq - [sender]
        if recipient.created_here
          QueuedEmail::LocationChange.create_email(sender, recipient, self)
        end
      end
    end
  end

################################################################################

protected

  def validate # :nodoc:
    if !self.north || (self.north > 90)
      errors.add(:north, :validate_location_north_too_high.t)
    end
    if !self.south || (self.south < -90)
      errors.add(:south, :validate_location_south_too_low.t)
    end
    if self.north && self.south && (self.north < self.south)
      errors.add(:north, :validate_location_north_less_than_south.t)
    end

    if !self.east || (self.east < -180) || (180 < self.east)
      errors.add(:east, :validate_location_east_out_of_bounds.t)
    end
    if !self.west || (self.west < -180) || (180 < self.west)
      errors.add(:west, :validate_location_west_out_of_bounds.t)
    end

    if self.high && self.low && (self.high < self.low)
      errors.add(:high, :validate_location_high_less_than_low.t)
    end

    if !self.user && !User.current
      errors.add(:user, :validate_location_user_missing.t)
    end

    if self.name.to_s.binary_length > 1024
      errors.add(:name, :validate_location_name_too_long.t)
    elsif self.name.empty?
      errors.add(:name, :validate_missing.t(:field => :name))
    end
  end
end
