# frozen_string_literal: true

# Note that each resolver only parses what makes sense in context,
# with a default fallback. So this could be an orderBy mega-list
# that contains superfluities unused by one or another model

module Types::Enums
  class NamesOrderBy < Types::BaseEnum
    value "WHEN", "When observed"
    value "CREATED_AT", "When created"
    value "UPDATED_AT", "When updated"
    value "TEXT_NAME", "Binomial name (w/o authority)"
    value "SEARCH_NAME", "Binomial name with authority"
    value "RANK", "Rank"
    value "CLASSIFICATION", "Classification"
    value "ICN_ID", "I.C.N."
    value "NUM_VIEWS", "Number of views"
  end
end
