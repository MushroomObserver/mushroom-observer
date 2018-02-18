module Query::Modules::NestedQueries
  attr_accessor :outer_id

  # This gives inner queries the ability to tweak the outer query.  For
  # example, this is a handy way to tell the outer query to skip outer results
  # that result in empty inner queries.
  #
  # This instance variabl is a Proc, initialized in the flavor-specific
  # initializer:
  #
  #   def initialize_inside_user
  #     ...
  #     self.tweak_outer_query = lambda do |outer|
  #       # This tells the outer query only to include users that have images
  #       # (i.e. have entries in the "images_users" many-to-many glue table).
  #       (outer.params[:join] ||= []) << :images_users
  #     end
  #   end
  #
  attr_accessor :tweak_outer_query

  # Each inner query corresponds to a single result of the outer query.  This
  # lets the inner query tell the corresponding +current_id+ of the outer
  # query.  By default, it gets it from a parameter of the same name as the
  # outer's model (e.g., <tt>params[:user]</tt> for inner queries nested inside
  # :User queries).
  #
  # This instance variable is a Proc, initialized in the flavor-specific
  # initializer.  For example, the default would look like this:
  #
  #   def initialize_inside_user
  #     ...
  #     self.outer_current_id = lambda do |inner|
  #       inner.params[:user]
  #     end
  #   end
  #
  attr_accessor :outer_current_id

  # This tells us how to create a new inner query based on another result of
  # the same outer query.  This is called, for example, when using the sequence
  # operators on an inner query.  When it runs out of results for the inner
  # query, it goes to the next result in the outer query, and creates a new
  # inner query corresponding to it.  By default, it just stores the outer
  # result (<tt>outer.current_id</tt>) in a parameter with the same name as the
  # outer query's model (e.g., <tt>params[:user] = outer.current_id</tt> for inn
  # queries nested inside :User queries).
  #
  # This instance variable is a Proc, initialized in the flavor-specific
  # initializer.  For example, the default would look like this:
  #
  #   def initialize_inside_user
  #     ...
  #     self.setup_new_inner_query = lambda do |new_params, new_outer|
  #       new_params[:user] = new_outer.current_id
  #     end
  #   end
  #
  attr_accessor :setup_new_inner_query

  # Is this query nested in an outer query?
  def has_outer?
    outer_id.present?
  end

  # Get instance for +outer_id+, modifying it slightly to skip results with
  # empty inner queries.
  def outer
    @outer ||= begin
      if outer_id
        outer = Query.find(outer_id)
        tweak_outer_query.call(outer) if tweak_outer_query
        outer
      end
    end
  end

  # Each inner query corresponds to a single result of the outer query.  This
  # method is called on the inner query, returning the +current_id+ of the outer
  # query for that result.
  def get_outer_current_id
    if outer_current_id
      outer_current_id.call(self)
    else
      params[outer.model.type_tag]
    end
  end

  # Create a new copy of this query corresponding to the new outer query.
  def new_inner(new_outer)
    new_params = params.merge(outer: new_outer.id)
    if setup_new_inner_query
      setup_new_inner_query.call(new_params, new_outer)
    else
      new_params[new_outer.model.type_tag] = new_outer.current_id
    end
    Query.lookup(model, flavor, new_params)
  end

  # Create a new copy of this query if the outer query changed, otherwise
  # returns itself unchanged.
  def new_inner_if_necessary(new_outer)
    if !new_outer
      nil
    elsif new_outer.current_id == get_outer_current_id
      self
    else
      self
      new_inner(new_outer)
    end
  end

  # Move outer query to first place.
  def outer_first
    outer.current_id = get_outer_current_id
    new_inner_if_necessary(outer.first)
  end

  # Move outer query to previous place.
  def outer_prev
    outer.current_id = get_outer_current_id
    new_inner_if_necessary(outer.prev)
  end

  # Move outer query to next place.
  def outer_next
    outer.current_id = get_outer_current_id
    new_inner_if_necessary(outer.next)
  end

  # Move outer query to last place.
  def outer_last
    outer.current_id = get_outer_current_id
    new_inner_if_necessary(outer.last)
  end
end
