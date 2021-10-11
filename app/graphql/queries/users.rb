# app/graphql/queries/users.rb
module Queries
    class Users < Queries::BaseQuery
        description 'list all users'
        type Types::UserType, null: false

        def resolve
            ::User.all
        end
    end
end
