class Query::ObservationAdvancedSearch < Query::Observation
  include Query::AdvancedSearch

  def parameter_declarations 
    super.merge(advanced_search_parameters)
  end

  def initialize
    initialize_advanced_search
    super
  end

  def add_join_to_names
    add_join(:names)
  end

  def add_join_to_users
    add_join(:users)
  end

  def add_join_to_locations
    add_join(:locations)
  end

  def content_join_spec
    :comments
  end
end
