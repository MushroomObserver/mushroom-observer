# frozen_string_literal: true

#
#  = Extensions to Hash
#
#  == Instance Methods
#
#  flatten::        Flatten multi-dimensional hash.
#  remove_nils!::   Remove keys whose value is nil.
#
################################################################################
#
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
    each do |key, val|
      val.is_a?(Hash) ? result.merge!(val.flatten) : result[key] = val
    end
    result
  end

  # Remove keys whose value is nil.
  def remove_nils!
    delete_if { |_k, v| v.nil? }
  end

  def add_leaf(*args)
    Tree.add_leaf(self, *args)
  end

  def has_node?(*args)
    Tree.has_node?(self, *args)
  end
end
