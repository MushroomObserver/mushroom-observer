# frozen_string_literal: true

# Form object for user login
# Handles login form data with proper field namespacing
class FormObject::Login < FormObject::Base
  attribute :login, :string
  attribute :password, :string
  attribute :remember_me, :boolean, default: false

  # Custom model_name to use "user" for field namespacing
  # This makes field names like user[login] instead of login[login]
  # to match existing controller expectations
  def self.model_name
    ActiveModel::Name.new(self, nil, "User")
  end
end
