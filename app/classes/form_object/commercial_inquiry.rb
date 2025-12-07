# frozen_string_literal: true

# Form object for commercial inquiry about an image
# Handles form data for image licensing inquiries
class FormObject::CommercialInquiry
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :message, :string

  # Field names like commercial_inquiry[message]
  def self.model_name
    ActiveModel::Name.new(self, nil, "CommercialInquiry")
  end
end
