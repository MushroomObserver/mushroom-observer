class Query::Specimen < Query::Base
  def model
    Specimen
  end

  def parameter_declarations
    super.merge(
    )
  end

  def initialize
    params[:by] ||= "herbarium_label"
    super
  end
end
