# frozen_string_literal: true

# A very basic query to check the context[:current_user] (if exists) created
# by the graphql_controller. Used in tests
module Queries
  class Visitor < Queries::BaseQuery
    description "get the current logged in visitor"
    type Types::Models::UserType, null: true

    def resolve
      return {} unless context[:current_user]

      context[:current_user]
    end
  end
end
