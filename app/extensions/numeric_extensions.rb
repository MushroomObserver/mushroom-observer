# frozen_string_literal: true

#
#  = Extensions to Numeric
#
#  == Instance Methods
#
#  to_radians::   Convert degrees to radians.
#
################################################################################

class Numeric
  def to_radians
    self * Math::PI / 180.0
  end
end
