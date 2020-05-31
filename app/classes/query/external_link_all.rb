# frozen_string_literal: true

class Query::ExternalLinkAll < Query::ExternalLinkBase
  def initialize_flavor
    add_sort_order_to_title
    super
  end
end
