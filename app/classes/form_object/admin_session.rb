# frozen_string_literal: true

# Form object for admin user switching form.
class FormObject::AdminSession
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :id, :string
end
