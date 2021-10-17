# app/graphql/queries/herbaria.rb
module Queries
  class Herbaria < Queries::BaseQuery
    description "list all herbaria"
    type [Types::HerbariumType], null: false

    def resolve
      ::Herbarium.all
    end
  end
end
