module Types
  class LogInInput < BaseInputObject
    description "Fields necessary for user login"
    # the name is usually inferred by class name but can be overwritten
    graphql_name "LogInInput"

    argument :login, String, required: true
    argument :password, String, required: true
  end
end
