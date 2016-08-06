class Query::LocationBase < Query::Base
  def model
    Location
  end

  def parameter_declarations
    super.merge(
      created_at?: [:time],
      updated_at?: [:time],
      users?:      [User],
      north?:      :float,
      south?:      :float,
      east?:       :float,
      west?:       :float
    )
  end

  def initialize_flavor
    initialize_model_do_time(:created_at)
    initialize_model_do_time(:updated_at)
    initialize_model_do_objects_by_id(:users)
    initialize_model_do_bounding_box(:location)
    super
  end

  def default_order
    "name"
  end
end
