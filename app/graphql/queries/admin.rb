# frozen_string_literal: true

module Queries
  class Admin < Queries::BaseQuery
    description "Is the current logged in visitor in admin mode?"
    type Boolean, null: false

    # A very basic query if we're in admin mode
    def resolve
      return false unless context[:in_admin_mode?]

      context[:in_admin_mode?]
    end
  end
end
