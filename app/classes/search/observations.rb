# frozen_string_literal: true

# Non-AR model for the faceted search form.
class Search::Observations < Search
  # Assign attributes from the Query::Observations.attribute_types hash,
  # adjusting for range fields and autocompleters with hidden id fields.
  assign_attributes(::Query::Observations)
end
