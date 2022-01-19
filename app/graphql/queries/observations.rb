# app/graphql/queries/observations.rb
# Experimental pagination

module Queries
  class Observations < Queries::BaseQuery
    description "list paginated observations"
    # type [Types::Models::ObservationType], null: false
    type [Types::Models::ObservationType.connection_type], null: false
  end
end
