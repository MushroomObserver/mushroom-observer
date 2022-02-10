# frozen_string_literal: true

module Mutations
  class BaseMutation < GraphQL::Schema::Mutation
    # include ActionPolicy::GraphQL::Behaviour
    argument_class Types::BaseArgument
    field_class Types::BaseField
    # input_object_class Inputs::BaseInputObject
    object_class Types::BaseObject

    # https://evilmartians.com/chronicles/graphql-on-rails-3-on-the-way-to-perfection
    def check_logged_in!
      return if context[:current_user]

      raise(GraphQL::ExecutionError.new("You need to login to perform this action"))
    end

    def check_admin!
      return if context[:in_admin_mode?]

      raise(GraphQL::ExecutionError.new("You need to be an admin to perform this action"))
    end

    def check_reviewer!
      return if context[:reviewer?]

      raise(GraphQL::ExecutionError.new("You need to be a reviewer to perform this action"))
    end
  end
end
