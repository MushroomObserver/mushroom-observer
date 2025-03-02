# frozen_string_literal: true

# Helper methods for turning Query parameters into SQL conditions.
module Query::Modules::Conditions
  # Just because these three are used over and over again.
  def add_owner_and_time_stamp_conditions(table = model.table_name)
    add_time_condition("#{table}.created_at", params[:created_at])
    add_time_condition("#{table}.updated_at", params[:updated_at])
    initialize_users_parameter
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

  # The method that all classes use for queries of their own ids.
  # Can accept an empty array of ids and respond accordingly.
  def add_id_in_set_condition(table = model.table_name, ids = :ids)
    return if params[ids].nil? # [] is valid

    set = clean_id_set(params[ids])
    @where << "#{table}.id IN (#{set})"
    @order = "FIND_IN_SET(#{table}.id,'#{set}') ASC" unless params[:order]

    @title_tag = :query_title_in_set.t(type: table.singularize.to_sym)
  end

  # table_col = foreign key of an association, e.g. `observations.location_id`
  def add_association_condition(table_col, ids, *, title_method: nil)
    return if ids.empty?

    if ids.size == 1
      send(title_method) if title_method && ids.first.present?
      @where << "#{table_col} = '#{ids.first}'"
    else
      set = clean_id_set(ids) # this produces a joined string!
      @where << "#{table_col} IN (#{set})"
    end
    add_joins(*)
  end

  def add_not_associated_condition(col, ids, *)
    return if ids.empty?

    set = clean_id_set(ids)
    @where << "#{col} NOT IN (#{set})"
    add_joins(*)
  end

  def add_subquery_condition(param, *, table: nil, col: :id)
    return if params[param].blank?

    sql = subquery_from_params(param).sql
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
