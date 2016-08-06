class Query::UserBase < Query::Base
  def model
    User
  end

  def parameter_declarations
    super.merge(
      created_at?: [:time],
      updated_at?: [:time]
    )
  end

  def initialize_flavor
    initialize_model_do_time(:created_at)
    initialize_model_do_time(:updated_at)
    super
  end

  def default_order
    "name"
  end
end
