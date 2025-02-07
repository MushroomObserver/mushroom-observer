# frozen_string_literal: true

# Helper methods for turning Query parameters into AR conditions.
module Query::Scopes::Shared
  # Just because these three are used over and over again.
  def add_owner_and_time_stamp_conditions
    add_time_condition(:created_at, params[:created_at])
    add_time_condition(:updated_at, params[:updated_at])
    add_id_condition(:user_id, lookup_users_by_name(params[:users]))
  end

  def add_date_condition(col, vals, joins)
    return if vals.empty?

    earliest, latest = vals
    @scope = @scope.date(earliest, latest, col)
    @scopes = @scopes.joins(joins) if joins
  end

  def add_time_condition(col, vals, joins)
    return unless vals

    earliest, latest = vals
    @scope = if latest
               @scope.datetime_between(col, earliest, latest)
             else
               @scope.datetime_after(col, earliest)
             end

    @scopes = @scopes.joins(joins) if joins
  end

  def add_by_user_condition
    return if params[:by_user].blank?

    user = find_cached_parameter_instance(User, :by_user)
    @scopes = @scopes.by_user(user)

    @title_tag = :query_title_by_user
    @title_args[:user] = user.legal_name
  end

  def add_by_editor_condition(type = model.type_tag)
    return unless params[:by_editor]

    user = find_cached_parameter_instance(User, :by_editor)
    @scopes = @scopes.by_editor(user)

    @title_tag = :query_title_by_editor
    @title_args[:user] = user.legal_name
    @title_args[:type] = type
  end

  def add_boolean_condition(true_cond, false_cond, val, joins)
    return if val.nil?

    @scopes = @scopes.send(:where, (val ? true_cond : false_cond))
    @scopes = @scopes.joins(joins) if joins
  end

  # Like boolean, but less verbose. When the column itself is boolean
  def add_boolean_column_condition(table_column, val, joins)
    return if val.nil?

    true_cond = table_column.eq(true)
    false_cond = table_column.eq(false)
    add_boolean_condition(true_cond, false_cond, val, joins)
  end

  # Shared by multiple Query model classes
  def initialize_ok_for_export_parameter
    add_boolean_column_condition(
      model.arel_table[:ok_for_export],
      params[:ok_for_export]
    )
  end

  # Like boolean, but less verbose. When you're querying for not nil
  def add_presence_condition(table_column, val, joins)
    return if val.nil?

    true_cond = table_column.not_eq(nil)
    false_cond = table_column.eq(nil)
    add_boolean_condition(true_cond, false_cond, val, joins)
  end

  # Like boolean, but less verbose
  def add_coalesced_presence_condition(table_column, val, joins)
    return if val.nil?

    true_cond = table_column.coalesce("").length.gt(0)
    false_cond = table_column.coalesce("").length.eq(0)
    add_boolean_condition(true_cond, false_cond, val, joins)
  end

  def add_exact_match_condition(table_column, vals, joins)
    return if vals.blank?

    vals = [vals] unless vals.is_a?(Array)
    vals = vals.map { |v| escape(v.downcase) }
    @scopes = @scopes.where(table_column.downcase.in(*vals))
    @scopes = @scopes.joins(joins) if joins
  end

  def add_range_condition(table_column, val, joins)
    return if val.blank? || val[0].blank? && val[1].blank?

    min, max = val
    @scopes = @scopes.where(table_column.gteq(min)) if min.present?
    @scopes = @scopes.where(table_column.lteq(max)) if max.present?
    @scopes = @scopes.joins(joins) if joins
  end

  def add_string_enum_condition(table_column, vals, allowed, joins)
    return if vals.empty?

    vals = vals.map(&:to_s) & allowed.map(&:to_s)
    return if vals.empty?

    @scopes = @scopes.where(table_column.in(*vals))
    @scopes = @scopes.joins(joins) if joins
  end

  # Send the whole enum Hash as `allowed`, so we can find the corresponding
  # values of the keys. MO's enum values currently may not start at 0.
  def add_indexed_enum_condition(table_column, vals, allowed, joins)
    return if vals.empty?

    vals = allowed.values_at(*vals)
    return if vals.empty?

    @scopes = @scopes.where(table_column.in(*vals))
    @scopes = @scopes.joins(joins) if joins
  end

  # Simply an id in set condition for the current table's :id column. No joins.
  # NOTE: this `reorder` seems backwards but the `&` builds the FIND_IN_SET
  # SQL correctly. Note the set comes first, and gets "quoted" in the SQL.
  #
  #   builds: "FIND_IN_SET(#{table}.id,'#{set}') ASC"
  #
  # rubocop:disable Metrics/AbcSize
  def add_ids_condition(table = model, ids_param = :ids)
    return if params[ids_param].nil? # [] is valid

    set = clean_id_set(params[ids_param])
    @scopes = @scopes.where(table[:id].in(set)).
              reorder(Arel::Nodes.build_quoted(set.join(",")) & table[:id])
    @title_tag = :query_title_in_set.t(type: table.singularize.to_sym)
  end
  # rubocop:enable Metrics/AbcSize

  # Generalized so the model and column name can be sent as params
  # e.g. (Observation[:location_id], ids) or (Location[:description_id], ids)
  def add_id_condition(table_column, ids, joins)
    return if ids.empty?

    set = clean_id_set(ids)
    @scopes = @scopes.where(table_column.in(set))
    @scopes = @scopes.joins(joins) if joins
  end

  def add_not_id_condition(table_column, ids, joins)
    return if ids.empty?

    set = clean_id_set(ids)
    @scopes = @scopes.where(table_column.not_in(set))
    @scopes = @scopes.joins(joins) if joins
  end

  # Put together a list of ids for use in a "id IN (1,2,...)" condition.
  #
  #   set = clean_id_set(name.children)
  #   @where << "names.id IN (#{set})"
  #
  def clean_id_set(ids)
    set = limited_id_set(ids).map(&:to_s).join(",")
    set.presence || "-1"
  end

  # array of max of MO.query_max_array unique ids for use with Arel "in"
  #    where(<x>.in(limited_id_set(ids)))
  def limited_id_set(ids)
    ids.map(&:to_i).uniq[0, MO.query_max_array]
  end

  # AR: `search_fields` should be defined in the Query class as either
  # model.arel_table[:column] or a concatenation of columns in parentheses.
  # e.g. Observation[:notes] or (Observation[:notes] + Observation[:name])
  # `pattern` should be a google-search-formatted string, for SearchParams.
  def add_pattern_condition
    return if params[:pattern].blank?

    @title_tag = :query_title_pattern_search
    search_columns(search_fields, params[:pattern])
  end
end
