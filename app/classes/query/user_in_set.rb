class Query::UserInSet < Query::UserBase
  include Query::Initializers::InSet

  def parameter_declarations
    super.merge(
      ids: [User]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor("users")
    super
  end
end
