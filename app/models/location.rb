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
#  display_name::  (V) Name, e.g.: "Lacy Park, Los Angeles Co., California, USA"
#  search_name::   (-) Name, e.g.: "lacy park los angeles co california usa"
#  north::         (V) North edge in degrees north, e.g. 37.8233
#  south::         (V) South edge in degrees north, e.g. 37.8035
#  east::          (V) East edge in degrees east, e.g. -122.173
#  west::          (V) West edge in degrees east, e.g. -122.204
#  high::          (V) Maximum elevation in meters, e.g. 100
#  low::           (V) Minimum elevation in meters, e.g. 0
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
      'display_name',
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
    'num_views',
    'last_view',
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
  def merge(old_loc)
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
    old_loc.log(:log_location_merged, :this => old_loc.display_name,
                 :that => self.display_name)

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
    if new_record? || display_name_changed?
      self.search_name = self.class.clean_name(display_name)
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

    if self.display_name.to_s.length > 200
      errors.add(:display_name, :validate_location_display_name_too_long.t)
    end
    if self.search_name.to_s.length > 200
      errors.add(:search_name, :validate_location_search_name_too_long.t)
    end
  end
end
