# frozen_string_literal: true

# Form object for inheriting classification from a parent name
class FormObject::InheritClassification < FormObject::Base
  attribute :parent, :string
  attribute :options, :integer
end
