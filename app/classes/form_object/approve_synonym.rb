# frozen_string_literal: true

# Form object for approving a name synonym
class FormObject::ApproveSynonym < FormObject::Base
  attribute :deprecate_others, :boolean, default: true
  attribute :comment, :string
end
