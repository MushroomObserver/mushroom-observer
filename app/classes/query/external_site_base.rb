class Query::ExternalSiteBase < Query::Base
  def model
    ExternalSite
  end

  def parameter_declarations
    super.merge(
      name?: :string
    )
  end

  def initialize_flavor
    initialize_model_do_search(:name, :name)
    super
  end

  def default_order
    "name"
  end
end
