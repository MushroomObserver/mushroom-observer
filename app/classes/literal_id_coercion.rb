# frozen_string_literal: true

# Shared Literal `prop` coercion blocks for props holding a database
# id (or array of ids) that arrive as raw HTTP params -- always a
# String (or Array<String>), never actually an Integer. Use via the
# `&` block-forwarding shorthand:
#
#   prop :some_id, _Nilable(Integer), default: nil, &TO_ID
#   prop :some_ids, _Nilable(_Array(Integer)), default: nil, &TO_ID_ARRAY
#
module LiteralIDCoercion
  # A single id: nil/"" stays nil, else Integer(value) -- raises
  # loudly on a non-numeric value instead of silently becoming 0.
  TO_ID = ->(value) { value.presence && Integer(value) }

  # An array of ids, e.g. Rails' array-mode checkbox params. Rails
  # checkbox-group forms emit a hidden `name="...[]" value=""`
  # sentinel alongside the real checkboxes so Rack doesn't drop the
  # whole param when nothing is checked -- `compact_blank` drops it
  # before coercing the rest. A request omitting the `[]` suffix
  # (`?key=5` instead of `?key[]=5`) hands Rack a bare String here
  # instead of an Array -- `is_a?(Array)` degrades that to nil rather
  # than raising NoMethodError on `.compact_blank`.
  TO_ID_ARRAY = lambda { |value|
    value.compact_blank.map { |id| Integer(id) } if value.is_a?(Array)
  }
end
