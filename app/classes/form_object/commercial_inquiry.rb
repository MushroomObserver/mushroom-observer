# frozen_string_literal: true

# Form object for commercial inquiry about an image
# Handles form data for image licensing inquiries
class FormObject::CommercialInquiry < FormObject::Base
  attribute :message, :string
end
