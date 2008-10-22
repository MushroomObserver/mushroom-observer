require_dependency 'active_record_extensions'
require_dependency 'acts_as_versioned_extensions'

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
#  6. has a history -- version number and asscociated PastLocation's
#
#  Public Methods:
#    north_west     [north, west]
#    north_east     [north, east]
#    south_west     [south, west]
#    south_east     [south, east]
#    center         [n+s/2, e+w/2]
#    set_search_name
#
################################################################################

class Location < ActiveRecord::Base
  belongs_to :user
  has_many :observations

  acts_as_versioned(:class_name => 'PastLocation', :table_name => 'past_locations')
  non_versioned_columns.push('created', 'search_name')
  ignore_if_changed('modified', 'user_id')

  def before_save
    self.set_search_name
  end

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

  def set_search_name
    str = self.display_name.to_ascii
    str.gsub!(/\W+/, ' ')
    str.gsub!(/ (a|an|the|in|on|of|as|at|by|to) /, ' ')
    self.search_name = str.strip.downcase
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
