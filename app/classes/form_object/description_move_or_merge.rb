# frozen_string_literal: true

# Form object for description move/merge actions.
# Provides attributes for target and delete-after option.
class FormObject::DescriptionMoveOrMerge < FormObject::Base
  attribute :target, :integer
  attribute :delete, :boolean, default: false

  def persisted?
    false
  end
end
