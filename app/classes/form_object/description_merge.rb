# frozen_string_literal: true

# Form object for merging descriptions.
# Provides attributes for target description and delete-after option.
class FormObject::DescriptionMerge < FormObject::Base
  attribute :target, :integer
  attribute :delete, :boolean, default: false

  def persisted?
    false
  end
end
