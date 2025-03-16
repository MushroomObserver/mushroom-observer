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

  # each_with_object doesn't work here in Hash
  # rubocop:disable Style/EachWithObject
  def deep_compact
    reduce({}) do |new_hash, (k, v)|
      unless v.nil?
        new_hash[k] = v.is_a?(Hash) ? v.deep_compact : v
      end
      new_hash
    end
  end

  def deep_compact_blank
    reduce({}) do |new_hash, (k, v)|
      if v.present?
        new_hash[k] = v.is_a?(Hash) ? v.deep_compact_blank : v
      end
      new_hash
    end
  end
  # rubocop:enable Style/EachWithObject

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
