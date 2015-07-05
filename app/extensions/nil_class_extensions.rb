# encoding: utf-8
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
  def any?(*args); return false; end
  def empty?;      return true;  end
end
