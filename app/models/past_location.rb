#
#  This model just stores old versions of Location's.  It saves *everything*
#  in the Location object, as well as a reference to the Location itself.
#  Should maybe share a base class with PastName?
#
#  Usage:
#    # Make some changes to a Location.
#    location.update_attributes(...)
#
#    # Create PastLocation if changes are "significant". (Remember to save.)
#    past_location = PastLocation.check_for_past_location(location)
#    past_location.save if past_location
#
#    # Look up old version of a Location.
#    PastLocation = PastLocation.find(
#      :conditions => ["location_id = ? AND version = ?", location.id, version]
#    )
#
#  Public Methods:
#    (many of the same methods Location supports)
#    PastLocation.check_for_past_location(loc)  Create PL if loc has changed.
#    PastLocation.make_past_location(loc)       Create PL.
#
#  NOTE: this model is subtly different from PastName.  In this model
#  check_for_past_location returns an *unsaved* PastLocation; in the other
#  check_for_past_name returns true or false, the PastName having already
#  been saved if one was created.
#
################################################################################

class PastLocation < ActiveRecord::Base
  belongs_to :location
  belongs_to :user
  
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

  # Create a PastLocation from a Location.  Doesn't do any checks and doesn't save the PastLocation
  def self.make_past_location(location)
    past_location = PastLocation.new
    past_location.location = location
    past_location.created = location.created
    past_location.modified = location.modified
    past_location.user_id = location.user_id
    past_location.version = location.version
    past_location.display_name = location.display_name
    past_location.notes = location.notes

    past_location.north = location.north
    past_location.south = location.south
    past_location.west = location.west
    past_location.east = location.east
    past_location.high = location.high
    past_location.low = location.low

    past_location
  end

  # Looks at the given location and compares it against what's in the database.
  # If a significant change has happened, then a PastLocation is created but
  # not saved.  The version number, modified and user for the location updated
  # as appropriate.  Return the PastLocation if successfully created. 
  def self.check_for_past_location(location, user=nil, logger=nil)
    result = nil
    if logger
      logger.warn('start check_for_past_location')
    end
    if location.id
      old_location = Location.find(location.id)
      if logger
        logger.warn("#{location.north} ? #{old_location.north}")
      end
      if (str_cmp(location.display_name, old_location.display_name) or
        str_cmp(location.notes, old_location.notes) or
        str_cmp(location.north, old_location.north) or
        str_cmp(location.south, old_location.south) or
        str_cmp(location.west, old_location.west) or
        str_cmp(location.east, old_location.east) or
        str_cmp(location.high, old_location.high) or
        str_cmp(location.low, old_location.low))
        past_location = make_past_location(old_location)
        location.version += 1
        location.modified = Time.now
        if user
          location.user = user
        end
        result = past_location
      end
    end
    result
  end

  private

  # Map nil or false to ''
  def self.str_cmp(s1, s2) # :nodoc:
    (s1 || '') != (s2 || '')
  end
end
