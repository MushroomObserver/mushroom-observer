# frozen_string_literal: true

# Note that each resolver only parses what makes sense in context,
# with a default fallback. So this could be an orderBy mega-list
# that contains superfluities unused by one or another model

module Types::Enums
  class ObservationsOrderBy < Types::BaseEnum
    value "WHEN", "When observed"
    value "CREATED_AT", "When created"
    value "UPDATED_AT", "When updated"
    value "TEXT_NAME", "Current name"
    # value "VOTES", "Votes"
    # value "IMAGE_VOTES", "Image Votes"
  end
end
