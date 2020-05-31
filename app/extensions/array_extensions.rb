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

  def add_leaf(*args)
    Tree.add_leaf(self, *args)
  end

  def has_node?(*args)
    Tree.has_node?(self, *args)
  end
end
