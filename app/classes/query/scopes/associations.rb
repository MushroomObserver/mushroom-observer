# frozen_string_literal: true

# Helper methods for turning Query parameters into AR conditions.
module Query::Scopes::Associations
  def initialize_users_parameter
    ids = lookup_users_by_name(params[:by_users])
    add_association_condition(:user_id, ids, title_method: :set_by_user_title)
  end

  def set_by_user_title
    user = find_cached_parameter_instance(User, :by_user)
    @title_tag = :query_title_by_user
    @title_args[:user] = user.legal_name
    user
  end

  def add_by_editor_condition(type = model.type_tag)
    return unless params[:by_editor]

    user = find_cached_parameter_instance(User, :by_editor)
    @scopes = @scopes.by_editor(user)

    @title_tag = :query_title_by_editor
    @title_args[:user] = user.legal_name
    @title_args[:type] = type
  end

  def initialize_herbaria_parameter(
    joins = { observations:
              { observation_herbarium_records: :herbarium_record } }
  )
    add_association_condition(
      HerbariumRecord[:herbarium_id],
      lookup_herbaria_by_name(params[:herbaria]),
      joins
    )
  end

  def initialize_herbarium_records_parameter
    add_association_condition(
      ObservationHerbariumRecord[:herbarium_record_id],
      lookup_herbarium_records_by_name(params[:herbarium_records]),
      { observations: :observation_herbarium_records }
    )
  end

  # pass a model (arel_table) for table
  def initialize_locations_parameter(table, vals, joins)
    return if vals.empty?

    ids = clean_id_set(lookup_locations_by_name(vals))
    conditions = table[:location_id].in(ids)
    # check for undefined location strings, often coming from mobile app:
    conditions = chain_location_string_conditions(conditions, table, vals)
    @scopes = @scopes.where(conditions)
    @scopes = @scopes.joins(**joins) if joins
    set_at_location_title if [vals].flatten.size == 1
  end

  def chain_location_string_conditions(conditions, model, vals)
    vals.each do |val|
      next unless /\D/.match?(val)

      conditions = conditions.or(model[:where].matches(val.clean_pattern))
    end
    conditions
  end

  def set_at_location_title
    location = find_cached_parameter_instance(Location, :location)
    @title_args[:location] = location.title_display_name
    location
  end

  def initialize_observations_parameter(
    table = "Observation#{model}".constantize,
    joins = table
  )
    ids = params[:observations]
    add_association_condition(
      table[:observation_id], ids, joins,
      title_method: :set_for_observation_title
    )
  end

  # Possible issue: the second arg below is the param name.
  # We're using it for both single and plural params.
  # It could work anyway, but the param names may soon be plural.
  def set_for_observation_title
    obs = find_cached_parameter_instance(Observation, :observation)
    @title_tag = :query_title_for_observation
    @title_args[:observation] = obs.unique_format_name
    obs
  end

  def initialize_projects_parameter(
    table = ProjectObservation,
    joins = { observations: :"#{table.table_name}" }
  )
    ids = lookup_projects_by_name(params[:projects])
    add_association_condition(
      table[:project_id], ids, joins, title_method: :set_for_project_title
    )
  end

  def set_for_project_title
    project = find_cached_parameter_instance(Project, :project)
    @title_tag = :query_title_for_project
    @title_args[:project] = project.title
    project
  end

  def initialize_species_lists_parameter(
    table = SpeciesListObservation,
    joins = { observations: :"#{table.table_name}" }
  )
    ids = lookup_species_lists_by_name(params[:species_lists])
    add_association_condition(
      table[:species_list_id], ids, joins,
      title_method: :set_in_species_list_title
    )
  end

  def set_in_species_list_title
    spl = find_cached_parameter_instance(SpeciesList, :species_list)
    @title_tag = :query_title_in_species_list
    @title_args[:species_list] = spl.format_name
    spl
  end
end
