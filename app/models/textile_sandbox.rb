# frozen_string_literal: true

# Simple model for the textile sandbox form.
# This is not backed by a database, just a struct to hold form data.
class TextileSandbox
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :code, :string
end
