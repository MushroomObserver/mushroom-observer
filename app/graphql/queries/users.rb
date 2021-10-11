# app/graphql/queries/users.rb
class Users < Queries::BaseQuery
    description 'list all users'
    
    type Types::UserType.connection_type, null: false
    def resolve
      ::User.all
    end
end
