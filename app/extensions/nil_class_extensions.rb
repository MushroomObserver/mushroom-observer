# frozen_string_literal: true

#
#  = Extensions to NilClass
#
#  == Instance Methods
#
#  any?::   Returns false.
#  empty?:: Returns true.
#
################################################################################

class NilClass
  def any?(*_args)
    false
  end

  def empty?
    true
  end
end
