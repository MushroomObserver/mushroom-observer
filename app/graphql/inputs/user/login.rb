# frozen_string_literal: true

module Inputs::User
  class Login < Inputs::BaseInputObject
    description "Credentials necessary for user login"
    # the name is usually inferred by class name but can be overwritten
    graphql_name "LoginUserInput"

    argument :login, String, required: true
    argument :password, String, required: true
    argument :remember_me, Boolean, required: false
  end
end
