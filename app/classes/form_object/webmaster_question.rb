# frozen_string_literal: true

# Form object for asking the webmaster a question
# Handles form data for anonymous or logged-in users
class FormObject::WebmasterQuestion
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :email, :string
  attribute :message, :string

  # Override model_name to control form field namespacing
  # This makes field names match controller expectations
  def self.model_name
    ActiveModel::Name.new(self, nil, "WebmasterQuestion")
  end
end
