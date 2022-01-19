# app/graphql/queries/location.rb
module Queries
  class Location < Queries::BaseQuery
    description "get location by id"
    type Types::Models::LocationType, null: false
    argument :id, Integer, required: true

    def resolve(id:)
      ::Location.find(id)
    end
  end
end
