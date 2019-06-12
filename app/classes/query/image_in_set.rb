class Query::ImageInSet < Query::ImageBase
  def parameter_declarations
    super.merge(
      ids: [Image]
    )
  end

  def initialize_flavor
    add_id_condition("images.id", params[:ids])
    super
  end
end
