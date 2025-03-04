# frozen_string_literal: true

#
#  = Extensions to TrueClass
#
#  == Instance Methods
#
#  to_boolean::   Returns true.
#  to_i::         Returns 1.
#
################################################################################

class TrueClass
  def to_boolean
    true
  end

  def to_i
    1
  end
end
