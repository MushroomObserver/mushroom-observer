# frozen_string_literal: true

#
#  = Extensions to NilClass
#
#  == Instance Methods
#
#  any?::         Returns false.
#  empty?::       Returns true.
#  to_boolean::   Returns false.
#
################################################################################

class NilClass
  def any?(*_args)
    false
  end

  def empty?
    true
  end

  def to_boolean
    false
  end
end
