module Types::Enums
  class OrderBy < Types::BaseEnum
    value "WHEN", "When observed"
    value "CREATED_AT", "When created"
    value "UPDATED_AT", "When updated"
    value "TEXT_NAME", "Current name"
    # value "VOTES", "Votes"
    # value "IMAGE_VOTES", "Image Votes"
  end
end
