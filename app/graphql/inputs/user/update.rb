# frozen_string_literal: true

# Input object for a userUpdate mutation
module Inputs
  module User
    class Update < Inputs::BaseInputObject
      description "Credentials necessary to update a user"
      # the name is usually inferred by class name but can be overwritten
      graphql_name "UserUpdateInput"

      argument :login, String, required: true
      argument :password, String, required: true
      argument :remember_me, Boolean, required: false, default_value: false,
                                      replace_null_with_default: true
    end
  end
end
