# frozen_string_literal: true

# Form object for submitting a merge request email to admins
# Allows users to request merging two objects (e.g., names or locations)
class FormObject::MergeRequest
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :notes, :string

  # Override model_name to control form field namespacing
  def self.model_name
    ActiveModel::Name.new(self, nil, "MergeRequest")
  end
end
