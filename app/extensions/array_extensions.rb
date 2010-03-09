#
#  = Extensions to Array
#
#  == Instance Methods
#
#  none?::    Same as <tt>!any?</tt>.
#  all?::     Same as <tt>!any?</tt> with the block negated.
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
end
