# frozen_string_literal: true

# include SearchObject for GraphQL. Docs: https://github.com/RStankov/SearchObjectGraphQL

module Resolvers
  class BaseSearchResolver < BaseResolver
    include SearchObject.module(:graphql)

    def escape_search_term(term)
      "%#{term.gsub(/\s+/, "%")}%"
    end
  end
end
