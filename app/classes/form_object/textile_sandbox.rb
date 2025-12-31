# frozen_string_literal: true

# Form object for the textile sandbox form.
# This is not backed by a database, just a struct to hold form data.
class FormObject::TextileSandbox
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :code, :string

  # Field names like textile_sandbox[code]
  def self.model_name
    ActiveModel::Name.new(self, nil, "TextileSandbox")
  end
end
