# frozen_string_literal: true

# Helper methods for turning Query parameters into SQL conditions.
module Query::Modules::GoogleSearch
  # For notes, see GoogleSearch class
  # Put together a bunch of SQL conditions that describe a given search.
  def google_conditions(search, field)
    goods = search.goods
    bads  = search.bads
    ands = []
    ands += goods.map do |good|
      or_clause(*good.map { |str| "#{field} LIKE '%#{clean_pattern(str)}%'" })
    end
    ands += bads.map { |bad| "#{field} NOT LIKE '%#{clean_pattern(bad)}%'" }
    [ands.join(" AND ")]
  end
end
