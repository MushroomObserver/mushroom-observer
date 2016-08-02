class Query::LocationDescription < Query::Base
  def model
    LocationDescription
  end

  def parameter_declarations
    super.merge(
      created_at?: [:time],
      updated_at?: [:time],
      users?: [User]
    )
  end

  def initialize_flavor
    initialize_model_do_time(:created_at)
    initialize_model_do_time(:updated_at)
    initialize_model_do_objects_by_id(:users)
    super
  end
end
