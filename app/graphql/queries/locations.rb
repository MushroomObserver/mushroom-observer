# app/graphql/queries/locations.rb
module Queries
  class Locations < Queries::BaseQuery
    description "list all locations"
    type [Types::Models::LocationType], null: false

    def resolve
      ::Location.all
    end
  end
end
