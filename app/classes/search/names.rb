# frozen_string_literal: true

# Non-AR model for the faceted search form.
class Search::Names < Search
  # Assign attributes from the Query::Names attributes hash,
  # adjusting for range fields and autocompleters with hidden id fields.
  # To switch to Query params, assign attribute(values[0], :date) etc.
  # and update the @field_columns hash in SearchController accordingly.
  # Then change the form to build a @query instead of a @filter, with
  # `pattern` being but one of the query params, and have the hydrator
  # in the SearchController#new action check the query instead of the
  # session[:pattern]
  Query::Names.attributes.map do |keyword, values|
    case values[1]
    when :parse_date_range
      attribute(keyword, :date)
      attribute(:"#{keyword}_range", :date)
    when :parse_rank_range
      attribute(keyword, :string)
      attribute(:"#{keyword}_range", :string)
    else
      attribute(keyword, :string)
    end
  end
end
