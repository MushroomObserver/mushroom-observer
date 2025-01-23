# frozen_string_literal: true

module Query::Scopes::AdvancedSearch
  def initialize_advanced_search
    name, user, location, content = google_parse_params
    make_sure_user_entered_something(name, user, location, content)
    add_name_condition(name)
    add_user_condition(user)
    add_location_condition(location)
    add_content_condition(content)
    @title_tag = :query_title_all_filtered # no longer set by flavor
  end

  def google_parse_params
    [
      SearchParams.new(phrase: params[:name]),
      SearchParams.new(phrase: User.remove_bracketed_name(params[:user].to_s)),
      SearchParams.new(phrase: params[:user_where]),
      SearchParams.new(phrase: params[:content])
    ]
  end

  def make_sure_user_entered_something(*args)
    return unless args.all?(&:blank?)

    raise(:runtime_no_conditions.t)
  end

  def add_name_condition(name)
    return if name.blank?

    add_search_conditions(name_field, name)
    add_join_to_names
  end

  def add_user_condition(user)
    return if user.blank?

    add_search_conditions(user_field, user)
    add_join_to_users
  end

  def add_location_condition(location)
    return if location.blank?

    add_search_conditions(location_field, location)
    add_join_to_locations
  end

  # This is a search for observation, location or name content, but it also
  # searches through comments on observations of the location or name.
  def add_content_condition(content)
    return if content.blank?

    # Could do left outer join from observations to comments, but it
    # takes longer.  Instead, break it into two queries, one without
    # comments, and another with inner join on comments.
    # self.executor = lambda do |args|
    #   content_search_one(content, args) | content_search_two(content, args)
    # end
    add_search_conditions(content_field_no_comments, content)
    @scopes = @scopes.joins(content_join_sources)
    add_search_conditions(content_field_with_comments, content)
  end

  # def content_search_one(content, args)
  #   args2 = args.dup
  #   extend_where(args2)
  #   args2[:where] += google_conditions(content, content_field_one)
  #   model.connection.select_rows(query(args2))
  # end

  # def content_search_two(content, args)
  #   args2 = args.dup
  #   extend_where(args2)
  #   extend_join(args2) << content_join_spec
  #   args2[:where] += google_conditions(content, content_field_two)
  #   model.connection.select_rows(query(args2))
  # end

  def name_field
    # "names.search_name"
    Name[:search_name]
  end

  def user_field
    # "CONCAT(users.login,users.name)"
    (User[:login] + User[:name])
  end

  def location_field
    if model == Location
      # "locations.name"
      Location[:name]
    elsif params[:search_location_notes]
      # "IF(locations.id,CONCAT(locations.name,locations.notes)," \
      # "observations.where)"
      Location[:id].
        when(true).then((Location[:name] + Location[:notes])).
        when(false).then(Observation[:where])
    else
      # "observations.where"
      Observation[:where]
    end
  end

  def content_field_no_comments
    # "observations.notes"
    Observation[:notes]
  end

  def content_field_with_comments
    # "CONCAT(observations.notes,comments.summary,comments.comment)"
    (Observation[:notes] + Comment[:summary] + Comment[:comment])
  end

  def content_join_sources
    if model == Observation
      :comments
    else
      { observations: :comments }
    end
  end
end
