#
#  = Extensions to Hash
#
#  == Instance Methods
#
#  flatten::    Flatten multi-dimensional hash.
#
################################################################################

class Hash
  # Flatten multi-dimensional hash in the style of link_to.  That is, it merges
  # all sub-hashes (ignoring the top-level key) into the top-level hash.
  #
  #   args = { :id => 5, :params => { :q => 123 } }
  #   puts args.flatten.inspect
  #   # { :id => 5, :q => 123 }
  #
  def flatten
    result = {}
    self.each do |key, val|
      if val.is_a?(Hash)
        result.merge!(val.flatten)
      else
        result[key] = val
      end
    end
    return result
  end
end
