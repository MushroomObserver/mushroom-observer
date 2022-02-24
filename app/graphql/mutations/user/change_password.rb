# frozen_string_literal: true

module Mutations
  module User
    class ChangePassword < Mutations::BaseMutation
      description "Change user password"

      argument :input, Inputs::User::ChangePassword, required: true

      type Types::Models::UserType

      def resolve(**input); end
    end
  end
end
