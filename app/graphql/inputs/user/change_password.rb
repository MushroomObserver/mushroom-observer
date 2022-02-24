# frozen_string_literal: true

# Input object for a userChangePassword mutation
module Inputs
  module User
    class ChangePassword < Inputs::BaseInputObject
      description "Credentials necessary for user to change password"
      # the name is usually inferred by class name but can be overwritten
      graphql_name "UserChangePasswordInput"

      argument :login, String, required: true
      argument :password, String, required: true
      argument :remember_me, Boolean, required: false, default_value: false,
                                      replace_null_with_default: true
    end
  end
end
