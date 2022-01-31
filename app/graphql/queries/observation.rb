# frozen_string_literal: true

# app/graphql/queries/observation.rb
module Queries
  class Observation < Queries::BaseQuery
    description "get observation by id"
    type Types::Models::ObservationType, null: false
    argument :id, Integer, required: true

    def resolve(id:)
      ::Observation.find(id)
    end
  end
end
