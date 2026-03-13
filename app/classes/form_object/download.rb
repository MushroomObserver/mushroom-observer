# frozen_string_literal: true

# Form object for the observations download form
class FormObject::Download < FormObject::Base
  attribute :format, :string, default: "raw"
  attribute :encoding, :string, default: "UTF-8"
end
