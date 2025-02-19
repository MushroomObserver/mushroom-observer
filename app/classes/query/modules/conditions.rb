# frozen_string_literal: true

# Helper methods for turning Query parameters into SQL conditions.
module Query::Modules::Conditions
  # Just because these three are used over and over again.
  def add_owner_and_time_stamp_conditions(table = model.table_name)
    add_time_condition("#{table}.created_at", params[:created_at])
    add_time_condition("#{table}.updated_at", params[:updated_at])
    ids = lookup_users_by_name(params[:users])
    add_id_condition("#{table}.user_id", ids)
  end

  def add_by_user_condition(table = model.table_name)
    return if params[:by_user].blank?

    user = find_cached_parameter_instance(User, :by_user)
    @title_tag = :query_title_by_user
    @title_args[:user] = user.legal_name
    where << "#{table}.user_id = '#{user.id}'"
  end

  def add_by_editor_condition(type = model.type_tag)
    return unless params[:by_editor]

    user = find_cached_parameter_instance(User, :by_editor)
    @title_tag = :query_title_by_editor
    @title_args[:user] = user.legal_name
    @title_args[:type] = type
    version_table = :"#{type}_versions"
    add_join(version_table)
    where << "#{version_table}.user_id = '#{user.id}'"
    where << "#{type}s.user_id != '#{user.id}'"
  end

  def add_pattern_condition
    return if params[:pattern].blank?

    @title_tag = :query_title_pattern_search
    add_search_condition(search_fields, params[:pattern])
  end

  def initialize_ok_for_export_parameter
    add_boolean_condition(
      "#{model.table_name}.ok_for_export IS TRUE",
      "#{model.table_name}.ok_for_export IS FALSE",
      params[:ok_for_export]
    )
  end

  def add_boolean_condition(true_cond, false_cond, val, *)
    return if val.nil?

    @where << (val ? true_cond : false_cond)
    add_joins(*)
  end

  def add_exact_match_condition(col, vals, *)
    return if vals.blank?

    vals = [vals] unless vals.is_a?(Array)
    vals = vals.map { |v| escape(v.downcase) }
    @where << if vals.length == 1
                "LOWER(#{col}) = #{vals.first}"
              else
                "LOWER(#{col}) IN (#{vals.join(", ")})"
              end
    add_joins(*)
  end

  def add_search_condition(col, val, *)
    return if val.blank?

    search = SearchParams.new(phrase: val)
    @where += google_conditions(search, col)
    add_joins(*)
  end

  def add_range_condition(col, val, *)
    return if val.blank?
    return if val[0].blank? && val[1].blank?

    min, max = val
    @where << "#{col} >= #{min}" if min.present?
    @where << "#{col} <= #{max}" if max.present?
    add_joins(*)
  end

  def add_string_enum_condition(col, vals, allowed, *)
    return if vals.empty?

    vals = vals.map(&:to_s) & allowed.map(&:to_s)
    return if vals.empty?

    @where << "#{col} IN ('#{vals.join("','")}')"
    add_joins(*)
  end

  # Send the whole enum Hash as `allowed`, so we can find the corresponding
  # values of the keys. MO's enum values currently may not start at 0.
  def add_indexed_enum_condition(col, vals, allowed, *)
    return if vals.empty?

    vals = allowed.values_at(*vals)
    return if vals.empty?

    @where << "#{col} IN (#{vals.join(",")})"
    add_joins(*)
  end

  # Generalized so the param can be :obs_ids or :desc_ids
  def add_ids_condition(table = model.table_name, ids = :ids)
    return if params[ids].nil? # [] is valid

    set = clean_id_set(params[ids])
    @where << "#{table}.id IN (#{set})"
    self.order = "FIND_IN_SET(#{table}.id,'#{set}') ASC"

    @title_tag = :query_title_in_set.t(type: table.singularize.to_sym)
    # @title_args[:by] = :query_sorted_by.t(field: :original_name)
    # @title_args[:descriptions] =
    #   :query_title_in_set.t(type: table.singularize.to_sym)
  end

  def add_id_condition(col, ids, *)
    return if ids.empty?

    set = clean_id_set(ids)
    @where << "#{col} IN (#{set})"
    add_joins(*)
  end

  def add_not_id_condition(col, ids, *)
    return if ids.empty?

    set = clean_id_set(ids)
    @where << "#{col} NOT IN (#{set})"
    add_joins(*)
  end

  def add_id_range_condition
    return unless (ids = params[:id_range])

    @where << ids.map do |term|
      if term.is_a?(Range)
        "#{model.table_name}.id >= #{term.begin} AND " \
        "#{model.table_name}.id <= #{term.end}"
      else
        "#{model.table_name}.id = #{term}"
      end
    end.join(" OR ")
  end

  def add_subquery_condition(param, *, table: nil, col: :id)
    return if params[param].blank?

    sql = subquery_from_params(param).query
    table ||= subquery_table(param)
    @where << "#{table}.#{col} IN (#{sql})"
    add_joins(*)
  end

  # Reconstitute the query from the subparam hash, adding the model.
  # parameter_declarations tells us the model name by subquery.
  def subquery_from_params(param)
    model = parameter_declarations[param][:subquery] # defined in each subclass
    Query.new(model, params[param])
  end

  # Look up a default subquery table from the parameter_declarations
  def subquery_table(param)
    model = parameter_declarations[param][:subquery]
    model.to_s.underscore.pluralize
  end

  def force_empty_results
    @where = ["FALSE"]
  end
end
