class Query::Specimen < Query::Base
  def model
    Specimen
  end

  def parameter_declarations
    super.merge(
    )
  end

  def initialize_flavor
    params[:by] ||= "herbarium_label"
    super
  end
end
