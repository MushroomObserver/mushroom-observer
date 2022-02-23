# frozen_string_literal: true

# Input object for a userLogin mutation
module Inputs
  module User
    class Login < Inputs::BaseInputObject
      description "Credentials necessary for user login"
      # the name is usually inferred by class name but can be overwritten
      graphql_name "UserLoginInput"

      argument :login, String, required: true
      argument :password, String, required: true
      argument :remember_me, Boolean, required: false
    end
  end
end
