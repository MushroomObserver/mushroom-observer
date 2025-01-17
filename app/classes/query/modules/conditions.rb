# frozen_string_literal: true

# Helper methods for turning Query parameters into SQL conditions.
module Query::Modules::Conditions
  # Just because these three are used over and over again.
  def add_owner_and_time_stamp_conditions(table = model.table_name)
    add_time_condition("#{table}.created_at", params[:created_at])
    add_time_condition("#{table}.updated_at", params[:updated_at])
    add_id_condition("#{table}.user_id", lookup_users_by_name(params[:users]))
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

    search = google_parse(val)
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

  def add_indexed_enum_condition(col, vals, allowed, *)
    return if vals.empty?

    vals = vals.filter_map { |v| allowed.index_of(v.to_sym) }
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
end
