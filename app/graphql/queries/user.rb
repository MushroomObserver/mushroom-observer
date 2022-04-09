# frozen_string_literal: true

# Query for a single user by id, login or full name
module Queries
  class User < Queries::BaseQuery
    description "get user by argument"
    type Types::Models::UserType, null: false
    argument :id, Integer, required: false
    argument :login, String, required: false
    argument :name, String, required: false

    def resolve(args)
      return {} unless args

      if args.key?(:id)
        ::User.find(args[:id])
      elsif args.key?(:login)
        ::User.find_by(login: args[:login])
      elsif args.key?(:name)
        ::User.find_by(name: args[:name])
      end
    end
  end
end
