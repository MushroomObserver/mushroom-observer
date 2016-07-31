class Query::SpeciesListAll < Query::SpeciesList
  include Query::All

  def initialize
    add_sort_order_to_title
    super
  end
end
