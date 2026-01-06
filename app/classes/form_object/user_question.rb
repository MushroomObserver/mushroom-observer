# frozen_string_literal: true

# Form object for asking another user a question
# Handles form data for user-to-user messages
class FormObject::UserQuestion < FormObject::Base
  attribute :subject, :string
  attribute :message, :string
end
