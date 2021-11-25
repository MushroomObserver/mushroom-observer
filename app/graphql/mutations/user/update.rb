# frozen_string_literal: true

module Mutations::User
  class Update < Mutations::BaseMutation
    description "Update user profile"

    # input_object_class Inputs::User::Update
    # argument :input, Inputs::User::Update, required: true

    type Types::Models::UserType

    # define return fields
    # field :user, Types::Models::UserType, null: false

    # define arguments
    # argument :id, Integer, required: true
    # argument :attributes, Inputs::UpdateUserInput, required: true

    # define resolve method
    def resolve(**arguments)
      # puts("Arguments\n")
      # puts(arguments)

      user_id = arguments[:id]
      user = User.find(user_id)
      # update does not need an ID.
      update_args = arguments.except(:id, :password)

      puts("Session user\n")
      puts(context[:current_user].inspect)
      puts("User to update\n")
      puts(user.inspect)
      # Add logic for authorization
      # if user.id != context[:current_user]

      # from application_controller.rb#check_permission(obj)
      if user != context[:current_user]
        raise(GraphQL::ExecutionError.new("You are not authorized to edit another user's profile."))
      end

      # puts("Update Arguments\n")
      # puts(update_args)
      # what we're returning
      if user.update(update_args)
        # return user
        user
      else
        raise(GraphQL::ExecutionError.new(user.errors.full_messages.join(", ")))
      end
    end
  end
end
