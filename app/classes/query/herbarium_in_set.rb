class Query::HerbariumInSet < Query::HerbariumBase
  def parameter_declarations
    super.merge(
      ids: [Herbarium]
    )
  end

  def initialize_flavor
    add_id_condition("herbaria.id", params[:ids])
    super
  end
end
