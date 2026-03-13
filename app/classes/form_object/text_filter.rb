# frozen_string_literal: true

# Generic form object for simple text filtering
# Provides starts_with and matches attributes for filtering lists
class FormObject::TextFilter < FormObject::Base
  attribute :starts_with, :string
  attribute :matches, :string
end
