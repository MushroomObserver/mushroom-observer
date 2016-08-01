class Query::Specimen < Query::Base
  def model
    Specimen
  end

  def parameter_declarations
    super.merge(
    )
  end

  def initialize_flavor
    super
  end

  def default_order
    "herbarium_label"
  end
end
