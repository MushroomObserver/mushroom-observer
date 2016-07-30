class Query::UserAll < Query::User
  include Query::All

  def initialize
    add_sort_order_to_title
  end
end
