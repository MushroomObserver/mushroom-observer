# frozen_string_literal: true

module Mutations::User
  class Delete < Mutations::BaseMutation
    description "Delete a user"
    # check logged in
    # check_logged_in!

    # input_object_class Inputs::DeleteUserInput

    # define return fields. deleted so no?
    field :user, Types::Models::User, null: false

    # define arguments
    argument :id, Integer, required: true
    # argument :attributes, Types::DeleteUserInput, required: true # require pw, for example?

    # define resolve method
    def resolve(id:, attributes:)
      delete_user = User.find(id)
      # Add logic for authorization
      # if user.id != context[:session_user]
      # The MO way is more complicated because admins
      # from application_controller.rb#check_permission(obj)
      unless check_permission(delete_user)
        raise(GraphQL::ExecutionError.new("You are not authorized to edit another user's profile."))
      end

      if delete_user.erase_user(attributes.to_h)
        { user: delete_user } # questionable if exists at this point, maybe just message
      else
        raise(GraphQL::ExecutionError.new(delete_user.errors.full_messages.join(", ")))
      end
    end
  end
end
