# frozen_string_literal: true

# app/graphql/queries/visitor.rb
# This is a very basic query for the :current_user, if exists
module Queries
  class Visitor < Queries::BaseQuery
    description "get the current logged in visitor"
    type Types::Models::UserType, null: false

    def resolve
      return {} unless context[:current_user]

      context[:current_user]
    end
  end
end
