module Mutations
  class DeleteUser < Mutations::BaseMutation
    # check logged in
    check_logged_in!

    # define return fields. deleted so no?
    field :user, Types::Models::User, null: false

    # define arguments
    argument :id, Integer, required: true
    argument :attributes, Types::UpdateUserInput, required: true

    # define resolve method
    def resolve(user:)
      user = User.find(id)
      # Add logic for authorization
      # if user.id != context[:session_user]
      # The MO way is more complicated because admins
      # from application_controller.rb#check_permission(obj)
      unless check_permission(user)
        raise(GraphQL::ExecutionError.new("You are not authorized to edit another user's profile."))
      end

      if user.erase_user(attributes.to_h)
        { user: user }
      else
        raise(GraphQL::ExecutionError.new(user.errors.full_messages.join(", ")))
      end
    end
  end
end
