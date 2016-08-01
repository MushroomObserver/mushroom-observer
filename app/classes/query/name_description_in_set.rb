class Query::NameDescsriptionInSet < Query::NameDescsription
  include Query::Initializers::InSet

  def parameter_declarations
    super.merge(
      ids: [NameDescsription]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor("name_descriptions")
    super
  end
end

