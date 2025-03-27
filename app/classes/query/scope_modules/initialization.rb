# frozen_string_literal: true

# Helper methods for turning Query parameters into AR conditions.
module Query::ScopeModules::Initialization
  attr_accessor :scopes, :order, :last_query

  def initialized?
    @initialized ? true : false
  end

  def initialize_query
    @initialized = true
    @order       = ""
    @scopes      = model
    initialize_scopes
    initialize_order
    @last_query  = sql
  end

  def sql
    initialize_query unless initialized?

    @sql = scopes.all.to_sql
  end

  def query
    initialize_query unless initialized?

    @query = scopes.all
  end

  def initialize_scopes
    # These strings can never come direct from user, so no need to sanitize.
    # (I believe they are only used by the site stats page. -JPH 20190708)
    self.where += params[:where] if params[:where]
    add_join(params[:join]) if params[:join]
    initialize_parameter_set
    filter_misspellings_for_name_queries
  end

  def initialize_parameter_set
    skippables = ["[]", "{}", ""].freeze # we need to keep false values!
    params.slice(*scope_parameters.keys).each do |param, val|
      next if (param == :id_in_set && val.nil?) || # keep empty array for this!
              (param != :id_in_set && skippables.include?(val.to_s))

      @scopes = if val.is_a?(Hash)
                  @scopes.send(param, **val)
                else
                  @scopes.send(param, val)
                end
    end
  end

  def filter_misspellings_for_name_queries
    return unless model == Name
    return if params[:misspellings].present

    @scopes = @scopes.with_correct_spelling
  end

  # Make a value safe for SQL.
  def escape(val)
    model.connection.quote(val)
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

  # Combine args into one parenthesized condition by ANDing them.
  def and_clause(*args)
    if args.length > 1
      # "(#{args.join(" AND ")})"
      starting = args.shift
      args.reduce(starting) { |result, arg| result.and(arg) }
    else
      args.first
    end
  end

  # Combine args into one parenthesized condition by ORing them.
  def or_clause(*args)
    if args.length > 1
      # "(#{args.join(" OR ")})"
      starting = args.shift
      args.reduce(starting) { |result, arg| result.or(arg) }
    else
      args.first
    end
  end

  # Add a join condition if it doesn't already exist.  There are two forms:
  #
  #   # Add join from root table to the given table:
  #   add_join(:observations)
  #     => join << :observations
  #
  #   # Add join from one table to another: (will create join from root to
  #   # first table if it doesn't already exist)
  #   add_join(:observations, :names)
  #     => join << {:observations => :names}
  #   add_join(:names, :descriptions)
  #     => join << {:observations => {:names => :descriptions}}
  #
  # def add_join(*)
  #   @join.add_leaf(*)
  # end

  # Same as add_join but can provide chain of more than two tables.
  # def add_joins(*args)
  #   if args.length == 1
  #     @join.add_leaf(args[0])
  #   elsif args.length > 1
  #     while args.length > 1
  #       @join.add_leaf(args[0], args[1])
  #       args.shift
  #     end
  #   end
  # end

  # Safely add to :where in +args+. Dups <tt>args[:where]</tt>,
  # casts it into an Array, and returns the new Array.
  def extend_where(args)
    extend_arg(args, :where)
  end

  # Safely add to :join in +args+.  Dups <tt>args[:join]</tt>, casts it into
  # an Array, and returns the new Array.
  def extend_join(args)
    extend_arg(args, :join)
  end

  # Safely add to +arg+ in +args+.  Dups <tt>args[arg]</tt>, casts it into
  # an Array, and returns the new Array.
  def extend_arg(args, arg)
    args[arg] = case old_arg = args[arg]
                when Symbol, String
                  [old_arg]
                when Array
                  old_arg.dup
                else
                  []
                end
  end
end
