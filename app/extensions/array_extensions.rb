# encoding: utf-8
#
#  = Extensions to Array
#
#  == Instance Methods
#
#  none?::             Same as <tt>!any?</tt>.
#  all?::              Same as <tt>!any?</tt> with the block negated.
#  to_boolean_hash::   Convert Array to Hash mapping elements to +true+.
#
################################################################################

class Array
  # Return true if none of the elements match.  The following are equivalent:
  #
  #   none? {|x| cond}
  #   !any? {|x| cond}
  #
  def none?(&block)
    proc = block || lambda {|x| x}
    self.each do |x|
      return false if proc.call(x)
    end
    return true
  end

  # Return true if all of the elements match.  The following are equivalent:
  #
  #   all? {|x| cond}
  #   !any? {|x| !cond}
  #
  def all?(&block)
    proc = block || lambda {|x| x}
    self.each do |x|
      return false if !proc.call(x)
    end
    return true
  end

  # Convert Array instance to Hash whose keys are the elements of the Array,
  # and whose values are all +true+.
  def to_boolean_hash
    hash = {}
    for item in self
      hash[item] = true
    end
    return hash
  end
end
