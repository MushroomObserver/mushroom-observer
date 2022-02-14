# frozen_string_literal: true

# require("graphql/batch")
# require("loaders/record_loader")
# no batch queries yet...

# This file defines all possible graphql queries (and their resolvers)
module Types
  class QueryType < Types::BaseObject
    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    field :user, resolver: Queries::User
    # field :users, Types::Models::UserType.connection_type, null: false,
    #       resolver: Queries::Users

    field :visitor, resolver: Queries::Visitor
    field :admin, resolver: Queries::Admin
  end
end
