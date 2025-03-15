# frozen_string_literal: true

# Helper methods for turning Query parameters into SQL conditions.
module Query::Modules::Associations
  def initialize_users_parameter(table = model.table_name)
    ids = lookup_users_by_name(params[:by_users])
    add_association_condition(
      "#{table}.user_id", ids
    )
  end

  def add_by_editor_condition(type = model.type_tag)
    return unless params[:by_editor]

    user = find_cached_parameter_instance(User, :by_editor)
    version_table = :"#{type}_versions"
    add_join(version_table)
    @where << "#{version_table}.user_id = '#{user.id}'"
    @where << "#{type}s.user_id != '#{user.id}'"
  end

  def initialize_herbaria_parameter(
    joins = [:observations, :observation_herbarium_records, :herbarium_records]
  )
    ids = lookup_herbaria_by_name(params[:herbaria])
    add_association_condition("herbarium_records.herbarium_id", ids, *joins)
  end

  def initialize_herbarium_records_parameter
    ids = lookup_herbarium_records_by_name(params[:herbarium_records])
    add_association_condition(
      "observation_herbarium_records.herbarium_record_id", ids,
      :observations, :observation_herbarium_records
    )
  end

  # This adds conditions both matching location ids, and where strings.
  def initialize_locations_parameter(table, vals, *)
    return if vals.empty?

    loc_col   = "#{table}.location_id"
    where_col = "#{table}.where"
    ids       = clean_id_set(lookup_locations_by_name(vals))
    cond      = "#{loc_col} IN (#{ids})"

    [vals].flatten.each do |val|
      if /\D/.match?(val.to_s)
        pattern = clean_pattern(val)
        cond += " OR #{where_col} LIKE '%#{pattern}%'"
      end
    end
    @where << cond
    add_joins(*)
  end

  def initialize_observations_parameter(
    table = :"observation_#{model.table_name}", joins = [table]
  )
    add_association_condition("#{table}.observation_id", params[:observations],
                              *joins)
  end

  def initialize_projects_parameter(table = :project_observations,
                                    joins = [:observations, table])
    ids = lookup_projects_by_name(params[:projects])
    add_association_condition("#{table}.project_id", ids, *joins)
  end

  def initialize_species_lists_parameter(
    table = :species_list_observations, joins = [:observations, table]
  )
    ids = lookup_species_lists_by_name(params[:species_lists])
    add_association_condition("#{table}.species_list_id", ids, *joins)
  end
end
