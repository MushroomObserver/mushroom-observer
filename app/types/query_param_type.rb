# frozen_string_literal: true

# MO Custom attribute type for all Query subclass attributes (parameters).
# The arg `:accepts` describes valid or parseable attribute values,
# according to the following syntax:
#
# = Simple value types
#   :string
#   :date
#   :time
#   :float
#   :boolean
#   SpeciesList (ActiveRecord model instance or id, parsed as an id)
#
# = Array value types
#   [:string]
#   [:date]
#   [:time]
#   [Project] (array of ActiveRecord model instances or ids, parsed as ids)
#
# = Hash value types
#   { string: [:yes, :no] } (evaluated as an "enum", other values ignored)
#   { boolean: [true] } (evaluated as an "enum", `false` ignored )
#   { subquery: :Observation } (evaluated as a subquery, sub-params forwarded)
#   { north:, south:, east:, west: } (forwarded as a hash of values)
#
# re: custom attribute types - https://stackoverflow.com/a/79417688/3357635
#                              https://stackoverflow.com/a/78668203/3357635
#
# NOTE: to retrieve the :accepts/:param_alias/:default_order/
#       :always_index/:redirect_to value for an attribute, you can call
#       the Query method `attribute_types`. Rails `type_for_attribute`
#       doesn't work.
#
#       Query::Observations.attribute_types[:has_sequences].accepts
#       Query::Observations.attribute_types[:projects].param_alias
#
class QueryParamType < ActiveModel::Type::Value
  attr_reader :accepts, :param_alias, :default_order, :always_index,
              :redirect_to

  # Add our custom args :accepts, :param_alias, :default_order,
  # :always_index, :redirect_to to the default args -- see `query_attr`
  # in app/extensions/class.rb.
  #
  # `always_index` defaults to nil (not `true`) so a consumer can tell
  # an undeclared attr apart from an explicit value -- record-backed and
  # scalar aliases interpret nil with opposite polarity (see
  # ApplicationController::QueryParamAliases).
  def initialize(accepts: nil, param_alias: nil, default_order: nil,
                 always_index: nil, redirect_to: :own_index)
    @accepts = accepts
    @param_alias = param_alias
    @default_order = default_order
    @always_index = always_index
    @redirect_to = redirect_to
    super()
  end

  # This is required and used if registering the type instead of just passing
  # the class (registered in config/initializers/active_model_types.rb)
  def type = :query_param
end
