# frozen_string_literal: true

module Queries
  class Visitor < Queries::BaseQuery
    description "get the current logged in visitor"
    type Types::Models::UserType, null: true

    # A very basic query for the :current_user, if exists
    def resolve
      return {} unless context[:current_user]

      context[:current_user]
    end
  end
end
