class Query::HerbariumInSet < Query::HerbariumBase
  include Query::Initializers::InSet

  def parameter_declarations
    super.merge(
      ids: [Herbarium]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor("herbaria")
    super
  end
end
