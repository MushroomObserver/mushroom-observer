class Query::SpeciesListAll < Query::SpeciesListBase
  def initialize_flavor
    add_sort_order_to_title
    super
  end
end
