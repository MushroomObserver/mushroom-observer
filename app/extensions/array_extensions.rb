# frozen_string_literal: true

#
#  = Extensions to Array
#
#  == Instance Methods
#
#  to_boolean_hash::   Convert Array to Hash mapping elements to +true+.
#
class Array
  # Convert Array instance to Hash whose keys are the elements of the Array,
  # and whose values are all +true+.
  def to_boolean_hash
    hash = {}
    each { |element| hash[element] = true }
    hash
  end

  # (Stolen forward from rails 3.1, BUT has slight differences??)
  def safe_join(sep = $OUTPUT_FIELD_SEPARATOR)
    sep = ERB::Util.html_escape(sep)
    map { |i| ERB::Util.html_escape(i) }.join(sep).html_safe
  end

  def add_leaf(*)
    Tree.add_leaf(self, *)
  end

  def has_node?(*)
    Tree.has_node?(self, *)
  end

  # Handy helper that replaces the original instances in an array of records
  # (simple instances without associations) with new instances (that have their
  # associations eager-loaded) while preserving the original order.
  # Useful for fragment caching, where only the uncached instances need
  # eager-loaded associations.
  def collate_new_instances(new_objects)
    map_id_to_new_object = new_objects.inject({}) do |obj, map|
      map[obj.id] = obj
    end
    new_objects.map { |obj| map_id_to_new_object[obj.id] || obj }
  end
end
