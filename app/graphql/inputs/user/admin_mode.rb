# frozen_string_literal: true

# Input object for a userAdminMode mutation
module Inputs
  module User
    class AdminMode < Inputs::BaseInputObject
      description "Credentials necessary for user admin mode change"
      # the name is usually inferred by class name but can be overwritten
      graphql_name "UserAdminModeInput"

      argument :login, String, required: true
      argument :password, String, required: true
      argument :remember_me, Boolean, required: false, default_value: false,
                                      replace_null_with_default: true
    end
  end
end
