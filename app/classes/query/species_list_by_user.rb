class Query::SpeciesListByUser < Query::SpeciesList
  def parameter_declarations
    super.merge(
      user: User
    )
  end

  def initialize_flavor
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    self.where << "species_lists.user_id = '#{user.id}'"
    super
  end
end
