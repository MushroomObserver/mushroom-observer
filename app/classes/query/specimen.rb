class Query::Specimen < Query::Base
  def parameter_declarations
    super.merge(
    )
  end

  def initialize
    params[:by] ||= "herbarium_label"
    super
  end
end
