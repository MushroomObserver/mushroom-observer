class Query::CommentAll < Query::Comment
  include Query::All

  def initialize
    add_sort_order_to_title
    super
  end
end
