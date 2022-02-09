# frozen_string_literal: true

# app/graphql/queries/user.rb
module Queries
  class User < Queries::BaseQuery
    description "get user by argument"
    type Types::Models::UserType, null: false
    argument :id, Integer, required: false
    argument :login, String, required: false
    argument :email, String, required: false
    argument :name, String, required: false

    # def resolve(id:)
    #   ::User.find(id)
    # use this for associations:
    # RecordLoader.for(User).load(id)
    # end

    def resolve(args)
      return {} unless args

      # puts(args)
      if args.key?(:id)
        ::User.find(args[:id])
      elsif args.key?(:login) # unreliable!
        ::User.find_by(login: args[:login])
      elsif args.key?(:email)
        ::User.find_by(email: args[:email].sub(/ <.*>$/, ""))
      elsif args.key?(:name)
        ::User.find_by(name: args[:name])
      end
    end
  end
end
