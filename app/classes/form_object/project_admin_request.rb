# frozen_string_literal: true

# Form object for requesting project admin access
class FormObject::ProjectAdminRequest
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :subject, :string
  attribute :content, :string

  def persisted?
    false
  end

  def self.model_name
    ActiveModel::Name.new(self, nil, "email")
  end
end
