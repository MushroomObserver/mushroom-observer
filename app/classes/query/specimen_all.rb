class Query::SpecimenAll < Query::Specimen
  include Query::Initializers::All

  def initialize
    add_sort_order_to_title
    super
  end
end
