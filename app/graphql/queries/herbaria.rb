# app/graphql/queries/herbaria.rb
# Experimental pagination

module Queries
  class Herbaria < Queries::BaseQuery
    description "list paginated herbaria"
    type [Types::HerbariumType.connection_type], null: false

    def resolve
      Connections::HerbariumConnection.new(Herbarium.order(:id))
    end
  end
end
