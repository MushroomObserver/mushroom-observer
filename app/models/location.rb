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
#  search_name::   (-) Name, e.g.: "lacy park los angeles co california usa"
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
#  set_search_name::    Before save: update search_name.
#  create_description:: After create: create (empty) official NameDescription.
#  notify_users::       After save: send email notification.
#
################################################################################

class Location < AbstractModel
  belongs_to :description, :class_name => 'LocationDescription' # (main one)
  belongs_to :rss_log
  belongs_to :user

  has_many :descriptions, :class_name => 'LocationDescription', :order => 'num_views DESC'
  has_many :comments,  :as => :object, :dependent => :destroy
  has_many :interests, :as => :object, :dependent => :destroy
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
    'description_id',
    'search_name'
  )

  before_save  :set_search_name
  after_update :notify_users

  # Automatically log standard events.
  self.autolog_events = [:created!, :updated!, :destroyed]

  # Callback whenever new version is created.
  versioned_class.before_save do |ver|
    ver.user_id = User.current_id
    if (ver.version != 1) and
       Location.connection.select_value(%(
         SELECT COUNT(*) FROM locations_versions
         WHERE location_id = #{ver.location_id} AND user_id = #{ver.user_id}
       )) == '0'
      SiteData.update_contribution(:add, :locations_versions)
    end
  end

  ##############################################################################
  #
  #  :section: Lat/Long Stuff
  #
  ##############################################################################

  # Return [north, west].
  def north_west
    [self.north, self.west]
  end

  # Return [north, east].
  def north_east
    [self.north, self.east]
  end

  # Return [south, west].
  def south_west
    [self.south, self.west]
  end

  # Return [south, east].
  def south_east
    [self.south, self.east]
  end

  # Return center as [lat, long].
  def center
    [(self.north + self.south)/2, (self.west + self.east)/2]
  end

  ##############################################################################
  #
  #  :section: Name Stuff
  #
  ##############################################################################

  def display_name()
    if User.current_location_format == :scientific
      Location.reverse_name(self.name())
    else
      self.name()
    end
  end

  def display_name=(val)
    if User.current_location_format == :scientific
      self.name = Location.reverse_name(val)
    else
      self.name = val
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
    "#{self.text_name} (#{self.id.to_s})"
  end

  # Same as +format_name+ but with id tacked on.
  def unique_format_name
    "#{self.format_name} (#{self.id.to_s})"
  end

  # Strip out special characters, punctuation, and small words from a name.
  # This is supposed to make it easier to search for a name if you don't know
  # how it is worded.  I'm not so sure anymore...
  #
  #   pattern = Location.clean_name(pattern)
  #   locs = Location.find_all(
  #     :conditions => ['search_name LIKE "%?%"', pattern]
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
    tokens = name.split(',').map { |x| x.strip() }
    tokens.delete("")
    return tokens.reverse.join(', ')
  end

  # Looks for a matching location using either location order just to be sure
  def self.search_by_name(name)
    result = find_by_name(name)
    if !result
      result = find_by_name(reverse_name(name))
    end
    result
  end
  
  def self.user_name(user, name)
    if user and (user.location_format == :scientific)
      Location.reverse_name(name)
    else
      name
    end
  end
  
  UNDERSTOOD_COUNTRIES = {
    "Africa" => 0,
    "Albania" => 0,
    "Antarctica" => 0,
    "Argentina" => 0,
    "Asia" => 0,
    "Australia" => 0,
    "Austria" => 0,
    "Bahamas" => 0,
    "Belize" => 0,
    "Bolivia" => 0,
    "Brazil" => 0,
    "Bulgaria" => 0,
    "Cambodia" => 0,
    "Canada" => 0,
    "Chile" => 0,
    "China" => 0,
    "Colombia" => 0,
    "Costa Rica" => 0,
    "Croatia" => 0,
    "Czech Republic" => 0,
    "Dominican Republic" => 0,
    "Ecuador" => 0,
    "England" => 0,
    "Europe" => 0,
    "Finland" => 0,
    "France" => 0,
    "Germany" => 0,
    "Greece" => 0,
    "Hungary" => 0,
    "India" => 0,
    "Indonesia" => 0,
    "Iran" => 0,
    "Israel" => 0,
    "Italy" => 0,
    "Japan" => 0,
    "Kenya" => 0,
    "Lebanon" => 0,
    "Macedonia" => 0,
    "Malaysia" => 0,
    "Mexico" => 0,
    "Morocco" => 0,
    "Namibia" => 0,
    "Netherlands" => 0,
    "New Zealand" => 0,
    "North America" => 0,
    "Norway" => 0,
    "Panama" => 0,
    "Poland" => 0,
    "Portugal" => 0,
    "Russia" => 0,
    "Scotland" => 0,
    "Slovenia" => 0,
    "South America" => 0,
    "South Africa" => 0,
    "South Korea" => 0,
    "Spain" => 0,
    "Sweden" => 0,
    "Switzerland" => 0,
    "Thailand" => 0,
    "Turkey" => 0,
    "United Kingdom" => 0,
    "USA" => 0,
    "Unknown" => 0
  }
  
  UNDERSTOOD_STATES = {
    "USA" => {
      "Alabama" => 0,
      "Alaska" => 0,
      "American Samoa" => 0,
      "Arizona" => 0,
      "Arkansas" => 0,
      "California" => 0,
      "Colorado" => 0,
      "Connecticut" => 0,
      "Delaware" => 0,
      "Federated States of Micronesia" => 0,
      "Florida" => 0,
      "Georgia" => 0,
      "Guam" => 0,
      "Hawaii" => 0,
      "Idaho" => 0,
      "Illinois" => 0,
      "Indiana" => 0,
      "Iowa" => 0,
      "Kansas" => 0,
      "Kentucky" => 0,
      "Louisiana" => 0,
      "Maine" => 0,
      "Marshall Islands" => 0,
      "Maryland" => 0,
      "Massachusetts" => 0,
      "Michigan" => 0,
      "Minnesota" => 0,
      "Mississippi" => 0,
      "Missouri" => 0,
      "Montana" => 0,
      "Nebraska" => 0,
      "Nevada" => 0,
      "New England" => 0,
      "New Hampshire" => 0,
      "New Jersey" => 0,
      "New Mexico" => 0,
      "New York" => 0,
      "North Carolina" => 0,
      "North Dakota" => 0,
      "Northern Mariana Islands" => 0,
      "Ohio" => 0,
      "Oklahoma" => 0,
      "Oregon" => 0,
      "Pacific Northwest" => 0,
      "Palau" => 0,
      "Pennsylvania" => 0,
      "Puerto Rico" => 0,
      "Rhode Island" => 0,
      "South Carolina" => 0,
      "South Dakota" => 0,
      "Tennessee" => 0,
      "Texas" => 0,
      "Utah" => 0,
      "Vermont" => 0,
      "Virgin Islands" => 0,
      "Virginia" => 0,
      "Washington" => 0,
      "Washington DC" => 0,
      "West Virginia" => 0,
      "Wisconsin" => 0,
      "Wyoming" => 0
    },
    "Australia" => {
      "Australian Capital Territory" => 0,
      "New South Wales" => 0,
      "Northern Territory" => 0,
      "Queensland" => 0,
      "South Australia" => 0,
      "Tasmania" => 0,
      "Victoria" => 0,
      "Western Australia" => 0
    },
    "Canada" => {
      "Alberta" => 0,
      "British Columbia" => 0,
      "Labrador" => 0,
      "Manitoba" => 0,
      "New Brunswick" => 0,
      "Newfoundland" => 0,
      "Newfoundland and Labrador" => 0,
      "Nova Scotia" => 0,
      "Ontario" => 0,
      "Prince Edward Island" => 0,
      "Quebec" => 0,
      "Saskatchewan" => 0,
      "Northwest Territories" => 0,
      "Nunavut" => 0,
      "Yukon" => 0,
    },
  }
  
  # Handling of '.'s
  BAD_TERMS = {
    "Hwy" => "Highway",
    "Hwy." => "Highway",
    "Mt" => "Mount",
    "Mt." => "Mount",
    "Mtn" => "Mountain",
    "Mtn." => "Mountain",
    " AL," => " Alabama,",
    " AK," => " Alaska,",
    " AS," => " American Samoa,",
    " AZ," => " Arizona,",
    " AR," => " Arkansas,",
    " CA," => " California,",
    " CT," => " Connecticut,",
    " DE," => " Delaware,",
    " Washington, DC," => " Washington DC,",
    " FM," => " Federated States of Micronesia,",
    " FL," => " Florida,",
    " GA," => " Georgia,",
    " GU," => " Guam,",
    " HI," => " Hawaii,",
    " ID," => " Idaho,",
    " IL," => " Illinois,",
    " IN," => " Indiana,",
    " IA," => " Iowa,",
    " KS," => " Kansas,",
    " KY," => " Kentucky,",
    " LA," => " Louisiana,",
    " ME," => " Maine,",
    " MH," => " Marshall Islands,",
    " MD," => " Maryland,",
    " MA," => " Massachusetts,",
    " MI," => " Michigan,",
    " MN," => " Minnesota,",
    " MS," => " Mississippi,",
    " MO," => " Missouri,",
    " MT," => " Montana,",
    " NE," => " Nebraska,",
    " NV," => " Nevada,",
    " NH," => " New Hampshire,",
    " NJ," => " New Jersey,",
    " NM," => " New Mexico,",
    " NY," => " New York,",
    " NC," => " North Carolina,",
    " ND," => " North Dakota,",
    " MP," => " Northern Mariana Islands,",
    " OH," => " Ohio,",
    " OK," => " Oklahoma,",
    " OR," => " Oregon,",
    " PW," => " Palau,",
    " PA," => " Pennsylvania,",
    " PR," => " Puerto Rico,",
    " RI," => " Rhode Island,",
    " SC," => " South Carolina,",
    " SD," => " South Dakota,",
    " TN," => " Tennessee,",
    " TX," => " Texas,",
    " UT," => " Utah,",
    " VT," => " Vermont,",
    " VI," => " Virgin Islands,",
    " VA," => " Virginia,",
    " WA," => " Washington,",
    " WV," => " West Virginia,",
    " WI," => " Wisconsin,",
    " WY," => " Wyoming,",
    " BC," => " British Columbia,",
    " ACT," => " Australian Capital Territory,",
    " NSW," => " New South Wales,",
    " QLD," => " Queensland,",
    " NP," => " National Park,",
    "County," => "Co.,",
    "CO" => "Co. or Colorado",
    "Road," => "Rd.,",
    "Street," => "St.,",
    "Avenue" => "Ave.",
    "Boulevard," => "Blvd.,",
    "United States of America" => "USA",
    "Washington, DC" => "Washington DC",
  }
  
  BAD_REGEXS = {
    /^[a-z]/ => "Location names should start with capitals"
  }
  
  OK_PREFIXES = ['Central', 'Interior', 'Northern', 'Southern', 'Eastern', 'Western', 'Northeastern', 'Northwestern', 'Southeastern', 'Southwestern']

  def self.understood_with_prefixes(candidate, understood_places)
    result = understood_places.member?(candidate)
    if not result
      tokens = candidate.split
      count = 0
      for s in tokens
        if OK_PREFIXES.member?(s)
          count += 1
        else
          if understood_places.member?(tokens[count..-1].join(' '))
            return true
          else
            return false
          end
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

  def self.location_exists(name)
    if name
      if @@location_cache.nil?
        @@location_cache = Location.connection.select_values("SELECT DISTINCT name FROM locations") +
	  Location.connection.select_values(%(
            SELECT DISTINCT `where` FROM `observations`
            WHERE `where` is not NULL
            ORDER BY `where`
          ))
      end
      @@location_cache.member?(name)
    else
      false
    end
  end
      
  # Decide if the given name is dubious for any reason
  def self.dubious_name?(name, reasons=false, check_db=true)
    reasons = []
    if not (check_db and location_exists(name))
      canonical_form = Location.reverse_name(Location.reverse_name(name))
      if canonical_form != name
        return true if !reasons
	      reasons.push("Not in canonical form: #{canonical_form}")
      end
      if name.index('Forest,').nil? and location_exists(no_dubious_county(name))
        return true if !reasons
        reasons.push("County may be redundant: #{name}")
      end
      a_country = country(name)
      if not understood_country?(a_country)
        return true if !reasons
        reasons.push("Unrecognized country: #{name}")
      end
      if has_known_states?(a_country)
        a_state = state(name)
        if a_state and not understood_state?(a_state, a_country)
	        return true if !reasons
          reasons.push("Unknown state: #{a_state}, #{a_country}")
        end
      end
      for key in BAD_TERMS.keys()
        if name.index(key)
          return true if !reasons
          reasons.push("Contains bad term: #{key} rather than #{BAD_TERMS[key]}")
        end
      end
    end
    return false if !reasons
    reasons
  end
  
  def self.country(name)
    name.split(',')[-1].strip()
  end
  
  def self.state(name)
    result = name.split(',')[-2]
    result.strip() if result
  end
  
  def self.dubious_country?(name)
    not understood_country?(country(name))
  end
  
  def self.no_dubious_county(name)
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

    # Update any users who call this location their primary location.
    for user in User.find_all_by_location_id(old_loc.id)
      user.location_id = self.id
      Transaction.put_user(
        :id           => user,
        :set_location => self
      )
    end

    # Move over any interest in the old name.
    for int in Interest.find_all_by_object_type_and_object_id('Location',
                                                              old_loc.id)
      int.object = self
      int.save
    end

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
    old_loc.log(:log_location_merged, :this => old_loc.name,
                 :that => self.name) if log

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

  # Callback that updates +search_name+ before saving a record.  See +clean_name+.
  def set_search_name
    if new_record? || name_changed?
      self.search_name = self.class.clean_name(name)
    end
  end

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

    if self.name.to_s.length > 200
      errors.add(:name, :validate_location_name_too_long.t)
    end
    if self.search_name.to_s.length > 200
      errors.add(:search_name, :validate_location_search_name_too_long.t)
    end
  end
end
