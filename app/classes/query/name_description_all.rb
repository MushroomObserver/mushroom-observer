class Query::NameDescriptionAll < Query::NameDescriptionBase
  include Query::Initializers::All

  def initialize_flavor
    add_sort_order_to_title
    super
  end

  def coerce_into_name_query
    Query.lookup(:Name, :with_descriptions, params)
  end
end
