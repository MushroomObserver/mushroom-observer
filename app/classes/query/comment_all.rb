module Query
  # All comments.
  class CommentAll < Query::CommentBase
    def initialize_flavor
      add_sort_order_to_title
      super
    end
  end
end
