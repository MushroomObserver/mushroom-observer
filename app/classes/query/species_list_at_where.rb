# frozen_string_literal: true

class Query::SpeciesListAtWhere < Query::SpeciesListBase
  def parameter_declarations
    super.merge(
      user_where?: :string # used to pass parameter to create_location
    )
  end

  def initialize_flavor
    location = params[:user_where]
    title_args[:where] = location
    pattern = clean_pattern(location)
    where << "species_lists.where LIKE '%#{pattern}%'"
    super
  end

  def default_order
    "name"
  end
end
