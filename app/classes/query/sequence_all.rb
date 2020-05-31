# frozen_string_literal: true

class Query::SequenceAll < Query::SequenceBase
  def initialize_flavor
    add_sort_order_to_title
    super
  end
end
