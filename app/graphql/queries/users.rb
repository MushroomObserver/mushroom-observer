# frozen_string_literal: true

# app/graphql/queries/users.rb
module Queries
  class Users < Queries::BaseQuery
    description "list all users"
    type [Types::Models::UserType.connection_type], null: false

    def resolve
      ::User.all
      # Connections::UsersConnection.new(User.order(:id))
    end
  end
end
