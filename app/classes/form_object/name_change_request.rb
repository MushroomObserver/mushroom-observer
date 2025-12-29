# frozen_string_literal: true

# Form object for requesting changes to taxonomic names
# Handles form data for name change request emails to admins
class FormObject::NameChangeRequest
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :notes, :string

  # Override model_name to control form field namespacing
  def self.model_name
    ActiveModel::Name.new(self, nil, "NameChangeRequest")
  end
end
