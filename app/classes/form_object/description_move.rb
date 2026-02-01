# frozen_string_literal: true

# Form object for moving descriptions to a synonym.
# Provides attributes for target name and delete-after option.
class FormObject::DescriptionMove < FormObject::Base
  attribute :target, :integer
  attribute :delete, :boolean, default: false

  def persisted?
    false
  end
end
