class Query::User < Query::Base
  def self.parameter_declarations
    super.merge(
      created_at?: [:time],
      updated_at?: [:time]
    )
  end

  def initialize
    initialize_model_do_time(:created_at)
    initialize_model_do_time(:updated_at)
  end

  def default_order
    "name"
  end
end
