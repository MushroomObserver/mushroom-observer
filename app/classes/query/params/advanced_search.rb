# frozen_string_literal: true

# Advanced search is really something like this:
# "Observation Search, or Locations or Names of Observations Search"
# It returns results by joining to observations and filtering the observations.
module Query::Params::AdvancedSearch
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    # NOTE: The autocompleters for name, location, and user all make the ids
    # available now, so this could be a lot more efficient.
    # But sometimes you're looking for strings that aren't ids.
    def advanced_search_parameter_declarations
      {
        search_name: :string,
        search_where: :string,
        search_user: :string,
        search_content: :string
      }.freeze
    end

    # These are the ones that if present, are definitive of advanced_search.
    def advanced_search_params
      advanced_search_parameter_declarations.keys.freeze
    end
  end

  delegate :advanced_search_params, to: :class
end
