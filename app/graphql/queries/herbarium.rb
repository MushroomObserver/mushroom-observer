# app/graphql/queries/herbarium.rb
module Queries
  class Herbarium < Queries::BaseQuery
    description "get herbarium by id"
    type Types::Models::Herbarium, null: false
    argument :id, Integer, required: true

    def resolve(id:)
      ::Herbarium.find(id)
    end
  end
end
