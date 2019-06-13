class Query::ImageInSet < Query::ImageBase
  def parameter_declarations
    super.merge(
      ids: [Image]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor
    super
  end
end
