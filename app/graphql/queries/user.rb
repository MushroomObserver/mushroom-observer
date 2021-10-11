# app/graphql/queries/user.rb
module Queries
    class User < Queries::BaseQuery
      description 'get user by id'
      
      type Types::UserType, null: false
      argument :id, Integer, required: true
      
      def resolve(id:)
        ::User.find(id)
      end
    end
end
  