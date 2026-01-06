# frozen_string_literal: true

# Form object for asking the webmaster a question
# Handles form data for anonymous or logged-in users
class FormObject::WebmasterQuestion < FormObject::Base
  attribute :email, :string
  attribute :message, :string
end
