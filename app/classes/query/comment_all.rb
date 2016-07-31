class Query::CommentAll < Query::Comment
  include Query::Initializers::All

  def flavor
    :all
  end

  def initialize
    add_sort_order_to_title
    super
  end
end
