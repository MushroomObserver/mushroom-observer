# frozen_string_literal: true

# Custom attribute type for Query subclass attributes (parameters).
# The arg `:accepts` describes valid or parseable attribute values,
# according to the following syntax:
#
# = Simple values
#   :string
#   :date
#   :time
#   :float
#   :boolean
#   SpeciesList (any ActiveRecord model instance or id, parsed as an id)
#
# = Array values
#   [:string]
#   [:date]
#   [:time]
#   [Project] (array of ActiveRecord model instances or ids, parsed as ids)
#
# = Hash values
#   { string: [:yes, :no] } (evaluated as an "enum", other values ignored)
#   { boolean: [true] } (evaluated as an "enum", `false` ignored )
#   { subquery: :Observation } (evaluated as a subquery, sub-params forwarded)
#   { north:, south:, east:, west:} (forwarded as a hash of values)
#
# re: custom types - https://stackoverflow.com/a/79417688/3357635
#
class QueryParamType < ActiveModel::Type::Value
  attr_reader :accepts

  def initialize(**args)
    @accepts = args[:accepts]
    super
  end

  # This is required and used if you register the type
  # instead of just passing the class
  def type = :query_param
end
