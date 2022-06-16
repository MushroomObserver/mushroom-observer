# frozen_string_literal: true

class Query::APIKeyAll < Query::APIKeyBase
  def initialize_flavor
    add_sort_order_to_title
    super
  end
end
