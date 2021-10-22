# frozen_string_literal: true

module Mutations::User
  class Update < Mutations::BaseMutation
    description "Update user profile"
    # check logged in
    # check_logged_in!

    input_object_class Inputs::User::Update

    # define return fields
    field :user, Types::Models::User, null: false

    # define arguments
    # argument :id, Integer, required: true
    # argument :attributes, Inputs::UpdateUserInput, required: true

    # define resolve method
    def resolve(**arguments)
      puts(arguments)
      user = User.find(arguments.input.id)
      # Add logic for authorization
      # if user.id != context[:session_user]
      # The MO way is more complicated because admins
      # from application_controller.rb#check_permission(obj)
      unless check_permission(user)
        raise(GraphQL::ExecutionError.new("You are not authorized to edit another user's profile."))
      end

      if user.update(arguments.to_h)
        { user: user }
      else
        raise(GraphQL::ExecutionError.new(user.errors.full_messages.join(", ")))
      end
    end
  end
end
