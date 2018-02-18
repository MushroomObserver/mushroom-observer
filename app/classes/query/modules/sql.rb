module Query::Modules::Sql
  attr_accessor :last_query

  # Build query for <tt>model.find_by_sql</tt> -- i.e. one that returns all
  # fields from the table in question, instead just the id.
  def query_all(args = {})
    query(args.merge(select: "DISTINCT #{model.table_name}.*"))
  end

  # Build query, allowing the caller to override/augment the standard
  # parameters.
  def query(args = {})
    initialize_query unless initialized?

    our_select  = args[:select] || "DISTINCT #{model.table_name}.id"
    our_join    = join.dup
    our_join += args[:join] if args[:join].is_a?(Array)
    our_join << args[:join] if args[:join].is_a?(Hash)
    our_join << args[:join] if args[:join].is_a?(Symbol)
    our_tables  = tables.dup
    our_tables += args[:tables] if args[:tables].is_a?(Array)
    our_tables << args[:tables] if args[:tables].is_a?(Symbol)
    our_from    = calc_from_clause(our_join, our_tables)
    our_where   = where.dup
    our_where += args[:where] if args[:where].is_a?(Array)
    our_where << args[:where] if args[:where].is_a?(String)
    our_where   = calc_where_clause(our_where)
    our_group   = args[:group] || group
    our_order   = args[:order] || order
    our_order   = reverse_order(order) if our_order == :reverse
    our_limit   = args[:limit]

    # Tack id at end of order to disambiguate the order.
    # (I despise programs that render random results!)
    if our_order.present? &&
       !our_order.match(/.id( |$)/)
      our_order += ", #{model.table_name}.id DESC"
    end

    sql = %(
      SELECT #{our_select}
      FROM #{our_from}
    )
    sql += "  WHERE #{our_where}\n"    if our_where.present?
    sql += "  GROUP BY #{our_group}\n" if our_group.present?
    sql += "  ORDER BY #{our_order}\n" if our_order.present?
    sql += "  LIMIT #{our_limit}\n"    if our_limit.present?

    @last_query = sql
    sql
  end

  # Format list of conditions for WHERE clause.
  def calc_where_clause(our_where = where)
    ands = our_where.uniq.map do |x|
      # Make half-assed attempt to cut down on proliferating parens...
      if x.match(/^\(.*\)$/) || !x.match(/ or /i)
        x
      else
        "(" + x + ")"
      end
    end
    ands.join(" AND ")
  end

  # Extract and format list of tables names from join tree for FROM clause.
  def calc_from_clause(our_join = join, our_tables = tables)
    implicits = [model.table_name] + our_tables
    result = implicits.uniq.map { |x| "`#{x}`" }.join(", ")
    if our_join
      result += " "
      result += calc_join_conditions(model.table_name, our_join).join(" ")
    end
    result
  end

  # Extract a complete list of tables being used by this query.  (Combines
  # this table (+model.table_name+) with tables from +join+ with custom-joined
  # tables from +tables+.)
  def table_list(our_join = join, our_tables = tables)
    flatten_joins([model.table_name] + our_join + our_tables, false).uniq
  end

  # Flatten join "tree" into a simple Array of Strings.  Set +keep_qualifiers+
  # to +false+ to tell it to remove the ".column" qualifiers on ambiguous
  # table join specs.
  def flatten_joins(arg = join, keep_qualifiers = true)
    result = []
    if arg.is_a?(Hash)
      for key, val in arg
        key = key.to_s.sub(/\..*/, "") unless keep_qualifiers
        result << key.to_s
        result += flatten_joins(val)
      end
    elsif arg.is_a?(Array)
      result += arg.map { |x| flatten_joins(x) }.flatten
    else
      arg = arg.to_s.sub(/\..*/, "") unless keep_qualifiers
      result << arg.to_s
    end
    result
  end

  # Figure out which additional conditions we need to connect all the joined
  # tables.  Note, +to+ can be an Array and/or tree-like Hash of dependencies.
  # (I believe it is identical to how :include is done in ActiveRecord#find.)
  def calc_join_conditions(from, to, done = [from.to_s])
    result = []
    from = from.to_s
    if to.is_a?(Hash)
      for key, val in to
        result += calc_join_condition(from, key.to_s, done)
        result += calc_join_conditions(key.to_s, val, done)
      end
    elsif to.is_a?(Array)
      result += to.map { |x| calc_join_conditions(from, x, done) }.flatten
    else
      result += calc_join_condition(from, to.to_s, done)
    end
    result
  end
end
