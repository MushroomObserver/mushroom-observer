module Mutations
  class BaseMutation < GraphQL::Schema::RelayClassicMutation
    argument_class Types::BaseArgument
    field_class Types::BaseField
    input_object_class Inputs::BaseInputObject
    object_class Types::BaseObject

    # https://evilmartians.com/chronicles/graphql-on-rails-3-on-the-way-to-perfection
    def check_authentication!
      return if context[:current_user]

      raise(GraphQL::ExecutionError.new("You need to authenticate to perform this action"))
    end
  end
end
