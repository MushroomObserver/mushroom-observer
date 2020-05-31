# frozen_string_literal: true

class Query::SpeciesListByUser < Query::SpeciesListBase
  def parameter_declarations
    super.merge(
      user: User
    )
  end

  def initialize_flavor
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    where << "species_lists.user_id = '#{user.id}'"
    super
  end
end
