# frozen_string_literal: true

#
#  = Extensions to FalseClass
#
#  == Instance Methods
#
#  to_boolean::   Returns false.
#  to_i::         Returns 0.
#
################################################################################

class FalseClass
  def to_boolean
    false
  end

  def to_i
    0
  end
end
