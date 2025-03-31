# frozen_string_literal: true

# https://stackoverflow.com/a/79417688/3357635
class QueryParamType < ActiveModel::Type::Value
  # This is required and used if you register the type
  # instead of just passing the class
  def type = :query_param
end
