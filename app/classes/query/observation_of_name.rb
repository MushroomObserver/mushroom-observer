class Query::ObservationOfName < Query::ObservationBase
  include Query::Initializers::OfName

  def parameter_declarations
    super.merge(of_name_parameter_declarations)
  end

  def initialize_flavor
    give_parameter_defaults
    names = target_names
    choose_a_title(names)
    add_name_conditions(names)
    super
  end

  def add_join_to_observations(table)
    add_join(table)
  end

  def coerce_into_image_query
    do_coerce(:Image)
  end

  def coerce_into_location_query
    do_coerce(:Location)
  end

  # TODO: need 'synonyms' flavor
  # params[:synonyms] == :all / :no / :exclusive
  # params[:misspellings] == :either / :no / :only
  # def coerce_into_name_query
  #   # This should result in a query with exactly one result, so the
  #   # resulting index should immediately display the actual location
  #   # instead of an index. Thus title and saving the old sort order are
  #   # unimportant.
  #   Query.lookup(:Name, :in_set, ids: params[:name])
  # end

  def do_coerce(new_model)
    Query.lookup(new_model, :with_observations_of_name, params_plus_old_by)
  end
end
