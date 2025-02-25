# frozen_string_literal: true

module Query::ScopeInitializers::AdvancedSearch
  def initialize_advanced_search
    # All of these params could be given - multiple filters possible
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

    add_join_to_names
    @scopes = @scopes.search_columns(name_field, name)
  end

  def add_user_condition(user)
    return if user.blank?

    add_join_to_users
    @scopes = @scopes.search_columns(user_field, user)
  end

  def add_location_condition(location)
    return if location.blank?

    add_join_to_locations
    @scopes = @scopes.search_columns(location_field, location)
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
    @scopes = @scopes.search_columns(content_field_no_comments, content)
    add_join_to_searchable_observation_content
    @scopes = @scopes.search_columns(content_field_with_comments, content)
  end

  def name_field
    Name[:search_name]
  end

  def user_field
    (User[:login] + User[:name])
  end

  def location_field
    if model == Location
      Location[:name]
    elsif params[:search_location_notes]
      Location[:id].
        when(true).then((Location[:name] + Location[:notes])).
        when(false).then(Observation[:where])
    else
      Observation[:where]
    end
  end

  def content_field_no_comments
    Observation[:notes]
  end

  def content_field_with_comments
    (Observation[:notes] + Comment[:summary] + Comment[:comment])
  end
end
