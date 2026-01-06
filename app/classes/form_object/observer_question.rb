# frozen_string_literal: true

# Form object for asking an observation owner a question
# Handles form data for observation-related messages
class FormObject::ObserverQuestion < FormObject::Base
  attribute :message, :string
end
