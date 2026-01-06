# frozen_string_literal: true

# Form object for requesting project admin access
class FormObject::ProjectAdminRequest < FormObject::Base
  attribute :subject, :string
  attribute :content, :string

  def persisted?
    false
  end

  # Custom model_name to match controller expectations
  def self.model_name
    ActiveModel::Name.new(self, nil, "email")
  end
end
