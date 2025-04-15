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
#
class QueryParamType < ActiveModel::Type::Value
  attr_reader :accepts

  # Add our custom arg :accepts to the default args.
  def initialize(precision: nil, limit: nil, scale: nil, accepts: nil)
    super(precision:, limit:, scale:)
    @accepts = accepts
  end

  # This is required and used if registering the type instead of just passing
  # the class (registered in config/initializers/active_model_types.rb)
  def type = :query_param
end
