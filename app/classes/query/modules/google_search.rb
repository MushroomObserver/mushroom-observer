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
      or_clause(*good.map { |str| "#{field} LIKE '%#{str.clean_pattern}%'" })
    end
    ands += bads.map { |bad| "#{field} NOT LIKE '%#{bad.clean_pattern}%'" }
    [ands.join(" AND ")]
  end
end
