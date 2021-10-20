# app/graphql/queries/observations.rb
# Experimental pagination

module Queries
  class Observations < Queries::BaseQuery
    description "list paginated observations"
    # type [Types::Models::Observation], null: false
    type [Types::Models::Observation.connection_type], null: false
  end
end
