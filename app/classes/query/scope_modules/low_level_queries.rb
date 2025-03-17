# frozen_string_literal: true

# lower level conditions to be added to Query AR
module Query::ScopeModules::LowLevelQueries
  # Execute query after wrapping select clause in COUNT().
  def select_count(args = {})
    initialize_query unless initialized?
    if executor
      executor.call(args).length
    else
      select = args[:select] || "DISTINCT #{model.table_name}.id"
      args = args.merge(select: "COUNT(#{select})")
      model.connection.select_value(sql(args)).to_i
    end
  end

  # Call model.connection.select_value.
  def select_value(args = {})
    initialize_query unless initialized?
    if executor
      executor.call(args).first.first
    else
      model.connection.select_value(sql(args))
    end
  end

  # Call model.connection.select_values.
  def select_values(args = {})
    initialize_query unless initialized?
    if executor
      executor.call(args).map(&:first)
    else
      model.connection.select_values(sql(args))
    end
  end

  # Call model.connection.select_rows.
  def select_rows(args = {})
    initialize_query unless initialized?
    if executor
      executor.call(args)
    else
      model.connection.select_rows(sql(args))
    end
  end

  # Call model.connection.select_one.
  def select_one(args = {})
    initialize_query unless initialized?
    if executor
      executor.call(args).first
    else
      model.connection.select_one(sql(args))
    end
  end

  # Call model.connection.select_all.
  def select_all(args = {})
    initialize_query unless initialized?
    raise("This query doesn't support low-level access!") if executor

    model.connection.select_all(sql(args)).to_a
  end

  # Call model.find_by_sql.
  def find_by_sql(args = {})
    initialize_query unless initialized?
    raise("This query doesn't support low-level access!") if executor

    model.find_by_sql(sql_select_all_columns(args))
  end

  # Return an Array of tables used in this query (Symbol's).
  def tables_used
    initialize_query unless initialized?
    table_list.map(&:to_s).sort.map(&:to_sym)
  end

  # Does this query use a given table?  (Takes String or Symbol.)
  def uses_table?(table)
    initialize_query unless initialized?
    table_list.map(&:to_s).include?(table.to_s)
  end

  # Does this query join to the given table? (Takes a Symbol; distinguishes
  # the different ways to join to a given table via the "table.field"
  # syntax used in +join_conditions+ table.)
  def uses_join?(join_spec)
    initialize_query unless initialized?
    uses_join_sub(join, join_spec)
  end

  def uses_join_sub(tree, arg) # :nodoc:
    case tree
    when Array
      tree.any? { |sub| uses_join_sub(sub, arg) }
    when Hash
      tree.key?(arg) ||
        tree.values.any? { |sub| uses_join_sub(sub, arg) }
    else
      (tree == arg)
    end
  end
end
