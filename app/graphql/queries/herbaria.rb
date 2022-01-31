# frozen_string_literal: true

# app/graphql/queries/herbaria.rb
# Experimental pagination

module Queries
  class Herbaria < Queries::BaseQuery
    description "list paginated herbaria"
    type [Types::Models::HerbariumType.connection_type], null: false

    def resolve
      ::Herbarium.all
      # Connections::HerbariumConnection.new(Herbarium.order(:id))
    end
  end
end
