# frozen_string_literal: true

# Form object for asking an observation owner a question
# Handles form data for observation-related messages
class FormObject::ObserverQuestion
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :message, :string

  # Field names like observer_question[message]
  def self.model_name
    ActiveModel::Name.new(self, nil, "ObserverQuestion")
  end
end
