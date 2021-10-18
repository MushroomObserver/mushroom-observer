# app/graphql/queries/observations.rb
# Experimental pagination

module Queries
  class Observations < Queries::BaseQuery
    description "list paginated observations"
    # type [Types::ObservationType], null: false
    type [Types::ObservationType.connection_type], null: false
  end
end
