# frozen_string_literal: true

# Form object for translation editing.
# Holds the tag being edited; persisted to force PATCH method.
class FormObject::Translation < FormObject::Base
  attribute :tag, :string

  def persisted?
    true
  end
end
