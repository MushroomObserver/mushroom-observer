class Query::SpecimenBase < Query::Base
  def model
    Specimen
  end

  def initialize_flavor
    super
  end

  def default_order
    "herbarium_label"
  end
end
