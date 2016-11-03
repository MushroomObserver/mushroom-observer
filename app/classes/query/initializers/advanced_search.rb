module Query::Initializers::AdvancedSearch
  def advanced_search_parameter_declarations
    {
      name?:     :string,
      location?: :string,
      user?:     :string,
      content?:  :string,
      search_location_notes?: :boolean
    }
  end

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
      google_parse(params[:name]),
      google_parse(params[:user].to_s.gsub(/ *<[^<>]*>/, "")),
      google_parse(params[:location]),
      google_parse(params[:content])
    ]
  end

  def make_sure_user_entered_something(*args)
    if args.all?(&:blank?)
      fail :runtime_no_conditions.t
    end
  end

  def add_name_condition(name)
    unless name.blank?
      self.where += google_conditions(name, "names.search_name")
      add_join_to_names
    end
  end

  def add_user_condition(user)
    unless user.blank?
      self.where += google_conditions(user, "CONCAT(users.login,users.name)")
      add_join_to_users
    end
  end

  def add_location_condition(location)
    unless location.blank?
      if model == Location
        val_spec = "locations.name"
      elsif params[:search_location_notes]
        val_spec = "IF(locations.id,CONCAT(locations.name,locations.notes),observations.where)"
      else
        val_spec = "IF(locations.id,locations.name,observations.where)"
      end
      self.where += google_conditions(location, val_spec)
      add_join_to_locations
    end
  end

  def add_content_condition(content)
    unless content.blank?

      # # This was the old query using left outer join to include comments.
      # self.join << case model
      # when Image       ; {:images_observations => {:observations => :comments!}}
      # when Location    ; {:observations => :comments!}
      # when Name        ; {:observations => :comments!}
      # when Observation ; :comments!
      # end
      # self.where += google_conditions(content,
      #   'CONCAT(observations.notes,IF(comments.id,CONCAT(comments.summary,comments.comment),""))')

      # Cannot do left outer join from observations to comments, because it
      # will never return.  Instead, break it into two queries, one without
      # comments, and another with inner join on comments.
      self.executor = lambda do |args|
        args2 = args.dup
        extend_where(args2)
        args2[:where] += google_conditions(content, "observations.notes")
        results = model.connection.select_rows(query(args2))

        args2 = args.dup
        extend_join(args2) << content_join_spec
        extend_where(args2)
        val_spec = "CONCAT(observations.notes,comments.summary,comments.comment)"
        args2[:where] += google_conditions(content, val_spec)
        results |= model.connection.select_rows(query(args2))
      end
    end
  end
end
