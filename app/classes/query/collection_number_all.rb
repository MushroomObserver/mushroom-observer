class Query::CollectionNumberAll < Query::CollectionNumberBase
  def initialize_flavor
    add_sort_order_to_title
    super
  end
end
