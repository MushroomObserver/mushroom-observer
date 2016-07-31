class Query::SpeciesListAll < Query::SpeciesList
  include Query::All

  def initialize_flavor
    add_sort_order_to_title
    super
  end
end
