# frozen_string_literal: true

# Form object for deprecating a name in favor of another
class FormObject::DeprecateSynonym < FormObject::Base
  attribute :proposed_name, :string
  attribute :is_misspelling, :boolean, default: false
  attribute :comment, :string
end
