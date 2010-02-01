#
#  = Location Model
#
#  Model to describe a location.  Locations are rectangular regions, not
#  points, with an associated free-form description.
#
#  == Version
#
#  Changes are kept in the "past_locations" table using
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
#  display_name::  (V) Name, e.g.: "Lacy Park, Los Angeles Co., California, USA"
#  search_name::   (-) Name, e.g.: "lacy park los angeles co california usa"
#  notes::         (V) Description.
#  north::         (V) North edge in degrees north, e.g. 37.8233
#  south::         (V) South edge in degrees north, e.g. 37.8035
#  east::          (V) East edge in degrees east, e.g. -122.173
#  west::          (V) West edge in degrees east, e.g. -122.204
#  high::          (V) Maximum elevation in meters, e.g. 100
#  low::           (V) Minimum elevation in meters, e.g. 0
#  license::       (V) License for description.
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
#  comments::           Comments about this Location. (not used yet)
#  interests::          Interests in this Location.
#
#  ==== Authors/editor methods
#  observations::       Observations at this Location.
#  editors::            List of User's who have changed this Location.
#  authors::            List of User's who have made "significant" changes.
#  add_editor::         Make given User an "author".
#  add_author::         Make given User an "editor".
#  remove_author::      Demote given User to "editor".
#
#  ==== Lat/long methods
#  north_west::         [north, west]
#  north_east::         [north, east]
#  south_west::         [south, west]
#  south_east::         [south, east]
#  center::             [n+s/2, e+w/2]
#
#  ==== Name methods
#  text_name::          Plain-text version of +display_name+.
#  format_name::        Alias for +display_name+ (for compatibility).
#  unique_text_name::   (same thing, with id tacked on to make unique)
#  unique_format_name:: (same thing, with id tacked on to make unique)
#
#  == Callbacks
#
#  set_search_name::    Before save: update search_name.
#  check_add_author::   After save: add owner as author.
#  notify_authors::     After save: send email notification.
#
################################################################################

class Location < AbstractModel
  belongs_to :license
  belongs_to :user

  has_many :comments,  :as => :object, :dependent => :destroy
  has_many :interests, :as => :object, :dependent => :destroy
  has_many :observations

  has_and_belongs_to_many :authors, :class_name => "User", :join_table => "authors_locations"
  has_and_belongs_to_many :editors, :class_name => "User", :join_table => "editors_locations"

  acts_as_versioned(
    :class_name => 'PastLocation',
    :table_name => 'past_locations',
    :if_changed => [
      'license_id',
      'display_name',
      'notes',
      'north',
      'south',
      'west',
      'east',
      'high',
      'low'
  ])
  non_versioned_columns.push(
    'sync_id',
    'created',
    'search_name'
  )

  before_save :update_user_if_save_version
  before_save :set_search_name
  after_save  :check_add_author
  after_save  :notify_authors

  # ----------------------------
  #  :section: Lat/Long Stuff
  # ----------------------------

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

  # ----------------------------
  #  :section: Name Stuff
  # ----------------------------

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
  def self.clean_name(str)
    str = str.to_ascii
    str.gsub!(/\W+/, ' ')
    str.gsub!(/ \w\w? /, ' ')
    return str.strip.downcase
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
    self.connection.select_values(%(
      SELECT DISTINCT IF(observations.location_id > 0, locations.display_name, observations.where) AS x
      FROM observations
      LEFT OUTER JOIN locations ON locations.id = observations.location_id
      #{where}
      ORDER BY observations.modified DESC
      LIMIT 100
    )).sort
  end

  # --------------------------------
  #  :section: Authors and Editors
  # --------------------------------

  # Add a User on as an "author".  Updates User contribution.
  #
  #   location.add_author(@user)
  #
  def add_author(user)
    if not self.authors.member?(user)
      self.authors.push(user)
      SiteData.update_contribution(:add, self, :authors_locations)
      if self.editors.member?(user)
        self.editors.delete(user)
        SiteData.update_contribution(:remove, self, :editors_locations)
      end
    end
  end

  # Demote a User to "author".  Updates User contribution.
  #
  #   location.remove_author(@user)
  #
  def remove_author(user)
    if self.authors.member?(user)
      self.authors.delete(user)
      SiteData.update_contribution(:remove, self, :authors_locations)
      # Add user as editor if (1) user isn't already an editor, and (2) the
      # user has made a change (i.e. owns at least one past_location).
      if not self.editors.member?(user) && !Location.connection.select_values(%(
          SELECT id FROM past_locations WHERE location_id = #{self.id} AND user_id = #{user.id}
        )).empty?
        self.editors.push(user)
        SiteData.update_contribution(:add, self, :editors_locations)
      end
    end
  end

  # Add a User on as an "editor".  Updates User contribution.
  #
  #   location.add_editor(@user)
  #
  def add_editor(user)
    if not self.authors.member?(user) and not self.editors.member?(user):
      self.editors.push(user)
      SiteData.update_contribution(:add, self, :editors_locations)
    end
  end

  # ----------------------------
  #  :section: Callbacks
  # ----------------------------

  # Callback that updates +search_name+ before saving a record.  See +clean_name+.
  def set_search_name
    if new_record? || display_name_changed?
      self.search_name = self.class.clean_name(display_name)
    end
  end

  # Callback that updates editors and/or authors after a User makes a change.
  #
  # If the Location has no author, they get promoted to author by default.
  # In all cases make sure the User is added on as an editor.
  #
  def check_add_author
    if authors.empty?
      add_author(user)
    else
      add_editor(user)
    end
  end

  # Callback after saving potential changes to a Location.  It determines if
  # the changes are important enough to notify the authors, and do so.
  def notify_authors

    # "altered?" is acts_as_versioned's equivalent to Rails's changed? method.
    # It only returns true if *important* changes have been made.
    if altered?
      sender = self.user || @user_making_change
      recipients = []
      # print "#{self.display_name} changed by #{sender ? sender.login : 'no one'}.\n"

      # Tell authors of the change.
      for user in self.authors
        recipients.push(user) if user.email_locations_author
      end

      # Tell editors of the change.
      for user in self.editors
        recipients.push(user) if user.email_locations_editor
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

    if self.display_name.to_s.length > 200
      errors.add(:display_name, :validate_location_display_name_too_long.t)
    end
    if self.search_name.to_s.length > 200
      errors.add(:search_name, :validate_location_search_name_too_long.t)
    end
  end
end
