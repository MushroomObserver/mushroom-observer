class Location < ActiveRecord::Base
  belongs_to :user
  
  protected
  def validate
    errors.add(:north, "should be at most 90") if north.nil? || (north > 90)
    errors.add(:south, "should be at least -90") if south.nil? || (south < -90)
    if north && south && (north < south)
      errors.add(:south, "should be less than north latitude")
    end

    errors.add(:west, "should be at most 180") if west.nil? || (west > 180)
    errors.add(:east, "should be at least -180") if east.nil? || (east < -180)

    errors.add(:low, "should be at most equal to the highest altitude") if high && low && (high < low)
  end 

  validates_presence_of :user, :version
  # validates_numericality_of :north, :south, :west, :east, :high, :low, :version
end
