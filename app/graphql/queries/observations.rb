# app/graphql/queries/observations.rb
module Queries
  class Observations < Queries::BaseQuery
    description "list all observations"
    type Types::ObservationType, null: false

    def resolve
      ::Observation.all
    end
  end
end
