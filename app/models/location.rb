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

  attr_display_names({
    :high  => "high elevation",
    :low   => "low elevation",
    :north => "north edge",
    :south => "south edge",
    :east  => "east edge",
    :west  => "west edge",
  })

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
  def validate
    errors.add(:north, "Latitude should be at most 90.") if north.nil? || (north > 90)
    errors.add(:south, "Latitude should be at least -90.") if south.nil? || (south < -90)
    if north && south && (north < south)
      errors.add(:north, "North latitude should be greater than south latitude.")
    end

    errors.add(:west, "Longitude should be between -180 and 180.") if west.nil? || (west < -180) || (180 < west)
    errors.add(:east, "Longitude should be between -180 and 180.") if east.nil? || (east < -180) || (180 < east)

    errors.add(:high, "High altitude should be at least equal to the lowest altitude.") \
      if high && low && (high < low)
  end

  validates_presence_of :user, :version
  # validates_numericality_of :north, :south, :west, :east, :high, :low, :version
end
