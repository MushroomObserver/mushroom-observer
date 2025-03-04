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

  def deep_find(key, object = self, found = [])
    found << object[key] if object.respond_to?(:key?) && object.key?(key)
    if object.is_a?(Enumerable)
      found << object.collect { |*a| deep_find(key, a.last) }
    end
    found.flatten.compact
  end

  # Remove keys whose value is nil.
  def remove_nils!
    delete_if { |_k, v| v.nil? }
  end

  def add_leaf(*)
    Tree.add_leaf(self, *)
  end

  def has_node?(*)
    Tree.has_node?(self, *)
  end
end
