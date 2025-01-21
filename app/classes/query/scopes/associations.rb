# frozen_string_literal: true

# Helper methods for turning Query parameters into AR conditions.
module Query::Scopes::Associations
  def initialize_herbaria_parameter(
    # joins = [:observations, :observation_herbarium_records, :herbarium_records]
    joins = { observations:
              { observation_herbarium_records: :herbarium_record } }
  )
    add_id_condition(
      # "herbarium_records.herbarium_id",
      HerbariumRecord[:herbarium_id],
      lookup_herbaria_by_name(params[:herbaria]),
      joins
    )
  end

  def initialize_herbarium_records_parameter
    add_id_condition(
      # "observation_herbarium_records.herbarium_record_id",
      ObservationHerbariumRecord[:herbarium_record_id],
      lookup_herbarium_records_by_name(params[:herbarium_records]),
      { observations: :observation_herbarium_records }
    )
  end

  # pass a model (arel_table)
  def add_where_condition(table, vals, joins)
    return if vals.empty?

    # loc_col   = "#{table}.location_id"
    # where_col = "#{table}.where"
    ids = clean_id_set(lookup_locations_by_name(vals))
    # cond      = "#{loc_col} IN (#{ids})"
    conditions = table[:location_id].in(ids)
    conditions = chain_where_conditions(conditions, table, vals)
    # @where << cond
    @scopes = @scopes.where(conditions)
    # add_joins(*)
    @scopes = @scopes.joins(joins) if joins
  end

  def chain_where_conditions(conditions, table, vals)
    vals.each do |val|
      next unless /\D/.match?(val)

      # cond += " OR #{where_col} LIKE '%#{pattern}%'"
      conditions = conditions.or(table[:where].matches(clean_pattern(val)))
    end
    conditions
  end

  # pass a model (arel_table)
  def add_at_location_condition(table)
    return unless params[:location]

    location = find_cached_parameter_instance(Location, :location)
    # @where << "#{table}.location_id = '#{location.id}'"
    @scopes = @scopes.where(table[:location_id].eq(location.id))

    @title_args[:location] = location.title_display_name
  end

  def add_is_collection_location_condition_for_locations
    return unless model == Location

    # where << "observations.is_collection_location IS TRUE"
    @scopes = @scopes.where(Observation[:is_collection_location].eq(true))
  end

  def add_for_observation_condition(
    table = "Observation#{model}".constantize,
    joins = :"observation_#{model.table_name}"
  )
    return if params[:observation].blank?

    obs = find_cached_parameter_instance(Observation, :observation)
    # where << "#{table}.observation_id = '#{obs.id}'"
    @scopes = @scopes.where(table[:observation_id].eq(obs.id))
    # add_join(*joins)
    @scopes = @scopes.joins(joins) if joins

    @title_tag = :query_title_for_observation
    @title_args[:observation] = obs.unique_format_name
  end

  def initialize_observations_parameter(
    # table = :"observation_#{model.table_name}",
    table = "Observation#{model}".constantize,
    joins = table
  )
    add_id_condition(
      # "#{table}.observation_id",
      table[:observation_id],
      params[:observations],
      joins
    )
  end

  def add_for_project_condition(table = model, joins = [table])
    return if params[:project].blank?

    project = find_cached_parameter_instance(Project, :project)
    # where << "#{table}.project_id = '#{params[:project]}'"
    @scopes = @scopes.where(table[:project_id].eq(project.id))
    add_is_collection_location_condition_for_locations
    # add_join(*joins)
    @scopes = @scopes.joins(joins) if joins

    @title_tag = :query_title_for_project
    @title_args[:project] = project.title
  end

  def initialize_projects_parameter(
    table = ProjectObservation,
    joins = { observations: :"#{table.table_name}" }
  )
    add_id_condition(
      # "#{table}.project_id",
      table[:project_id],
      lookup_projects_by_name(params[:projects]),
      joins
    )
  end

  def add_in_species_list_condition(
    table = SpeciesListObservation,
    joins = { observations: :"#{table.table_name}" }
  )
    return if params[:species_list].blank?

    spl = find_cached_parameter_instance(SpeciesList, :species_list)
    # where << "#{table}.species_list_id = '#{spl.id}'"
    @scopes = @scopes.where(table[:species_list_id].eq(spl.id))
    add_is_collection_location_condition_for_locations
    # add_join(*joins)
    @scopes = @scopes.joins(joins) if joins

    @title_tag = :query_title_in_species_list
    @title_args[:species_list] = spl.format_name
  end

  def initialize_species_lists_parameter(
    table = SpeciesListObservation,
    joins = { observations: :"#{table.table_name}" }
  )
    add_id_condition(
      # "#{table}.species_list_id",
      table[:species_list_id],
      lookup_species_lists_by_name(params[:species_lists]),
      joins
    )
  end
end
