# frozen_string_literal: true

module Query::Initializers::AdvancedSearch
  # Initialized only on locations, obs, names queries - note images disabled
  def initialize_advanced_search
    name, user, location, content = google_parse_params
    make_sure_user_entered_something(name, user, location, content)
    add_name_condition(name)
    add_user_condition(user)
    add_location_condition(location)
    add_content_condition(content)
  end

  def google_parse_params
    [
      SearchParams.new(phrase: params[:search_name]),
      SearchParams.new(
        phrase: User.remove_bracketed_name(params[:search_user].to_s)
      ),
      SearchParams.new(phrase: params[:search_where]),
      SearchParams.new(phrase: params[:search_content])
    ]
  end

  def make_sure_user_entered_something(*args)
    return unless args.all?(&:blank?)

    raise(:runtime_no_conditions.t)
  end

  def add_name_condition(name)
    return if name.blank?

    @where += google_conditions(name, name_field)
    add_join_to_names
  end

  def add_user_condition(user)
    return if user.blank?

    @where += google_conditions(user, user_field)
    add_join_to_users
  end

  def add_location_condition(location)
    return if location.blank?

    @where += google_conditions(location, location_field)
    add_join_to_locations
  end

  def add_content_condition(content)
    return if content.blank?

    # Cannot do left outer join from observations to comments, because it
    # will never return.  Instead, break it into two queries, one without
    # comments, and another with inner join on comments.
    @executor = lambda do |args|
      content_search_one(content, args) | content_search_two(content, args)
    end
  end

  def content_search_one(content, args)
    args2 = args.dup
    extend_where(args2)
    args2[:where] += google_conditions(content, content_field_one)
    model.connection.select_rows(sql(args2))
  end

  def content_search_two(content, args)
    args2 = args.dup
    extend_where(args2)
    extend_join(args2) << content_join_spec
    args2[:where] += google_conditions(content, content_field_two)
    model.connection.select_rows(sql(args2))
  end

  def name_field
    "names.search_name"
  end

  def user_field
    "CONCAT(users.login,users.name)"
  end

  def location_field
    if model == Location
      "locations.name"
    else
      "observations.where"
    end
  end

  def content_field_one
    "observations.notes"
  end

  def content_field_two
    "CONCAT(observations.notes,comments.summary,comments.comment)"
  end
end
