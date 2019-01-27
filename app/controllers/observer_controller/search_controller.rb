# TODO: move this into a new SearchController
class ObserverController
  # This is the action the search bar commits to.  It just redirects to one of
  # several "foreign" search actions:
  #   comment/image_search
  #   image/image_search
  #   location/location_search
  #   name/name_search
  #   observer/observation_search
  #   observer/user_search
  #   project/project_search
  #   species_list/species_list_search
  def pattern_search # :nologin: :norobots:
    pattern = param_lookup([:search, :pattern]) { |p| p.to_s.strip_squeeze }
    type = param_lookup([:search, :type], &:to_sym)

    # Save it so that we can keep it in the search bar in subsequent pages.
    session[:pattern] = pattern
    session[:search_type] = type

    case type
    when :observation, :user
      ctrlr = :observer
    when :comment, :herbarium, :image, :location,
      :name, :project, :species_list, :herbarium_record
      ctrlr = type
    when :google
      if pattern.blank?
        redirect_to(action: :list_rss_logs)
      else
        search = URI.escape("site:#{MO.domain} #{pattern}")
        redirect_to("https://google.com/search?q=#{search}")
      end
      return
    else
      flash_error(:runtime_invalid.t(type: :search, value: type.inspect))
      redirect_back_or_default(action: :list_rss_logs)
      return
    end

    # If pattern is blank, this would devolve into a very expensive index.
    if pattern.blank?
      redirect_to(controller: ctrlr, action: "list_#{type}s")
    else
      redirect_to(controller: ctrlr, action: "#{type}_search",
                  pattern: pattern)
    end
  end

  # Advanced search form.  When it posts it just redirects to one of several
  # "foreign" search actions:
  #   image/advanced_search
  #   location/advanced_search
  #   name/advanced_search
  #   observer/advanced_search
  def advanced_search_form # :nologin: :norobots:
    @filter_defaults = users_content_filters || {}
    return unless request.method == "POST"

    model = params[:search][:model].to_s.camelize.constantize
    query_params = {}
    add_filled_in_text_fields(query_params)
    add_applicable_filter_parameters(query_params, model)
    query = create_query(model, :advanced_search, query_params)
    redirect_to(add_query_param({ controller: model.show_controller,
                                  action: :advanced_search },
                                query))
  end

  def add_filled_in_text_fields(query_params)
    [:content, :location, :name, :user].each do |field|
      val = params[:search][field].to_s
      next unless val.present?

      # Treat User field differently; remove angle-bracketed user name,
      # since it was included by the auto-completer only as a hint.
      if field == :user
        val = val.sub(/ <.*/, "")
      end
      query_params[field] = val
    end
  end

  def add_applicable_filter_parameters(query_params, model)
    ContentFilter.by_model(model).each do |fltr|
      query_params[fltr.sym] = params[:"content_filter_#{fltr.sym}"]
    end
  end

  # Displays matrix of advanced search results.
  def advanced_search # :nologin: :norobots:
    if params[:name] || params[:location] || params[:user] || params[:content]
      search = {}
      search[:name] = params[:name] if params[:name].present?
      search[:location] = params[:location] if params[:location].present?
      search[:user] = params[:user] if params[:user].present?
      search[:content] = params[:content] if params[:content].present?
      search[:search_location_notes] = params[:search_location_notes].present?
      query = create_query(:Observation, :advanced_search, search)
    else
      query = find_query(:Observation)
    end
    show_selected_observations(query)
  rescue => err
    flash_error(err.to_s) if err.present?
    redirect_to(controller: "observer", action: "advanced_search_form")
  end
end
