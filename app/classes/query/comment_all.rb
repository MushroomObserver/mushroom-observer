# frozen_string_literal: true

class Query::CommentAll < Query::CommentBase
  def initialize_flavor
    add_sort_order_to_title
    super
  end
end
