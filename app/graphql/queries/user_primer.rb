# frozen_string_literal: true

# Query for a list of most frequent users for the autocomplete
module Queries
  class UserPrimer < Queries::BaseQuery
    description "Get list of users to prime an autocomplete"
    type [Types::Models::UserType], null: false

    def resolve
      ::User.primer
    end
  end
end
