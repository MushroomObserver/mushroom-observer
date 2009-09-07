require_dependency 'active_record_extensions'
require_dependency 'acts_as_versioned_extensions'
require_dependency 'site_data'

################################################################################
#
#  Model to describe a location.  Locations are rectangular regions, not
#  points.  Each location:
#
#  1. has a name
#  2. has notes
#  3. has north, south, east and west edges
#  4. has an elevation
#  5. belongs to a User (who created it originally)
#  6. has zero or more authors (who have made significant contributions)
#  7. has zero or more editors (who have made relatively minor edits)
#  8. has a history -- version number and asscociated PastLocation's
#
#  Class Methods:
#    Location.primer(user)  Get list of user's latest observation to prime auto-completer.
#
#  Names:
#    display_name           Name of location, textile formatting okay.
#    search_name            Name of location with punctuation and small words removed.
#    text_name              Plain-text version of name.
#    unique_text_name       Same, with id tacked on.
#    format_name            Alias for display_name (for compatibility with other objects).
#    unique_format_name     Same, with id tacked on.
#
#  Lat/Long Methods:
#    north_west             [north, west]
#    north_east             [north, east]
#    south_west             [south, west]
#    south_east             [south, east]
#    center                 [n+s/2, e+w/2]
#
#  Authors/Editors:
#    add_author(user)       Make given user an "author".
#    add_editor(user)       Make given user an "editor".
#    remove_author(user)    Demote given user to "editor".
#    check_add_author       Callback to check if user should become author.
#
#  Other Methods:
#    set_search_name        Callback used to set "search_name" after changes.
#    notify_authors         Callback used to notify people of changes.
#
################################################################################

class Location < ActiveRecord::Base
  has_and_belongs_to_many :authors, :class_name => "User", :join_table => "authors_locations"
  has_and_belongs_to_many :editors, :class_name => "User", :join_table => "editors_locations"
  belongs_to :user
  has_many :observations

  acts_as_versioned(:class_name => 'PastLocation', :table_name => 'past_locations')
  non_versioned_columns.push('created', 'search_name')
  ignore_if_changed('modified', 'user_id')

  before_save :set_search_name
  before_save :check_add_author
  after_save :notify_authors

  def north_west
    [self.north, self.west]
  end

  def north_east
    [self.north, self.east]
  end

  def south_west
    [self.south, self.west]
  end

  def south_east
    [self.south, self.east]
  end

  def center
    [(self.north + self.south)/2, (self.west + self.east)/2]
  end

  def text_name; self.display_name.t.html_to_ascii; end
  def format_name; self.display_name; end
  def unique_text_name; "#{self.text_name} (#{self.id.to_s})"; end
  def unique_format_name; "#{self.format_name} (#{self.id.to_s})"; end

  def self.primer(user)
    self.connection.select_values(%(
      SELECT DISTINCT IF(observations.location_id > 0, locations.display_name, observations.where) AS x
      FROM observations
      LEFT OUTER JOIN locations ON locations.id = observations.location_id
      WHERE observations.user_id = #{user.id}
      ORDER BY observations.modified DESC
      LIMIT 100
    )).sort
  end

  def set_search_name
    str = self.display_name.to_ascii
    str.gsub!(/\W+/, ' ')
    str.gsub!(/ (a|an|the|in|on|of|as|at|by|to) /, ' ')
    self.search_name = str.strip.downcase
  end

  # Used to decide initially which locations should have authors.
  def check_add_author
    if north && south && east && west && self.authors == []
      add_author(self.user)
    end
  end

  # Add a user on as an "author".
  def add_author(user)
    if not self.authors.member?(user)
      self.authors.push(user)
      user.reload.contribution
      user.contribution += FIELD_WEIGHTS[:authors_locations]
      if self.editors.member?(user)
        self.editors.delete(user)
        user.contribution -= FIELD_WEIGHTS[:editors_locations]
      end
      user.save
    end
  end

  # Demote a user to "editor".
  def remove_author(user)
    if self.authors.member?(user)
      self.authors.delete(user)
      user.reload.contribution
      user.contribution -= FIELD_WEIGHTS[:authors_locations]
      if not self.editors.member?(user) && !Location.connection.select_values(%(
          SELECT id FROM past_locations WHERE location_id = #{self.id} AND user_id = #{user.id}
        )).empty?
        self.editors.push(user)
        user.contribution += FIELD_WEIGHTS[:editors_locations]
      end
      user.save
    end
  end

  # Add a user on as an "editor".
  def add_editor(user)
    if not self.authors.member?(user) and not self.editors.member?(user):
      self.editors.push(user)
      self.save
      user.reload.contribution
      user.contribution += FIELD_WEIGHTS[:editors_locations]
      user.save
    end
  end

  # Call this after saving potential changes to a Location.  It will determine
  # if the changes are important enough to notify the authors, and do so.
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
# print "Notifying author: #{user.login}\n" if user.email_locations_author && user != sender
      end

      # Tell editors of the change.
      for user in self.editors
        recipients.push(user) if user.email_locations_editor
# print "Notifying editor: #{user.login}\n" if user.email_locations_editor && user != sender
      end

      # Tell masochists who want to know about all location changes.
      for user in User.find_all_by_email_locations_all(true)
        recipients.push(user)
# print "Notifying masochist: #{user.login}\n" if user != sender
      end

      # Send to people who have registered interest.
      # Also remove everyone who has explicitly said they are NOT interested.
      for interest in Interest.find_all_by_object(self)
        if interest.state
          recipients.push(interest.user)
# print "Notifying interested party: #{user.login}\n" if user != sender
        else
          recipients.delete(interest.user)
# print "Un-notifying disinterested party: #{user.login}\n" if user != sender
        end
      end

      # Send notification to all except the person who triggered the change.
      for recipient in recipients.uniq - [sender]
        LocationChangeEmail.create_email(sender, recipient, self)
      end
    end
  end

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

    if !self.user
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
