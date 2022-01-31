# frozen_string_literal: true

module Inputs::User
  class Create < Inputs::BaseInputObject
    description "Fields necessary for first user Sign-up"
    # the name is usually inferred by class name but can be overwritten
    graphql_name "CreateUserInput"

    argument :login, String, required: true
    argument :name, String, required: true
    argument :email, String, required: true
    argument :password, String, required: true
    argument :password_confirmation, String, required: true
  end
end
