# frozen_string_literal: true

# Form object for asking another user a question
# Handles form data for user-to-user messages
class FormObject::UserQuestion
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :subject, :string
  attribute :message, :string

  # Field names like user_question[subject], user_question[message]
  def self.model_name
    ActiveModel::Name.new(self, nil, "UserQuestion")
  end
end
