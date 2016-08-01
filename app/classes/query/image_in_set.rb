class Query::ImageInSet < Query::Image
  include Query::Initializers::InSet

  def parameter_declarations
    super.merge(
      ids: [Image]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor("images")
    super
  end
end
