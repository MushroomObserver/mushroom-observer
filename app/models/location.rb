require 'active_record_extensions'

class Location < ActiveRecord::Base
  belongs_to :user
  has_many :observations
  has_many :past_locations

  attr_display_names({
    :high  => "high elevation",
    :low   => "low elevation",
    :north => "north edge",
    :south => "south edge",
    :east  => "east edge",
    :west  => "west edge",
  })
  
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
