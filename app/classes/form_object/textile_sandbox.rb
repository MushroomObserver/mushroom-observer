# frozen_string_literal: true

# Form object for the textile sandbox form.
# This is not backed by a database, just a struct to hold form data.
class FormObject::TextileSandbox < FormObject::Base
  attribute :code, :string
end
