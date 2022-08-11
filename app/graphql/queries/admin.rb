# frozen_string_literal: true

# A very basic query to find if graphql_controller context is in admin mode
module Queries
  class Admin < Queries::BaseQuery
    description "Is the current logged in visitor in admin mode?"
    type Boolean, null: false

    def resolve
      return false unless context[:in_admin_mode?]

      context[:in_admin_mode?]
    end
  end
end
