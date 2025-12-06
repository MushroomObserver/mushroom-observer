# frozen_string_literal: true

# Form object for asking the observation owner a question
# Handles form data for the observer question email
class FormObject::ObserverQuestion
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :message, :string

  # Override model_name to control form field namespacing
  # This makes field names match controller expectations (question[message])
  def self.model_name
    ActiveModel::Name.new(self, nil, "Question")
  end
end
