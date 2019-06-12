# frozen_string_literal: true
# TODO: move this into a new SearchController

# Handle "pattern" and "advanced" searches
class ObserverController
  ##### Pattern Search #####

  # valid pattern search types
  PATTERN_SEARCH_TYPES = [
    :comment,
    :herbarium,
    :herbarium_record,
    :google,
    :image,
    :location,
    :name,
    :observation,
    :project,
    :species_list,
    :user
  ].freeze

  # types with special default patterns:
  # If the pattern is a bare value, it defaults to synonym_of:"value"
  SYNONYM_PATTERN_TYPES = [
    :name,
    :observation
  ].freeze

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
  def pattern_search
    pattern = param_lookup([:search, :pattern]) { |p| p.to_s.strip_squeeze }
    type = param_lookup([:search, :type], &:to_sym)

    unless PATTERN_SEARCH_TYPES.include?(type)
      flash_error(:runtime_invalid.t(type: :search, value: type.inspect))
      redirect_back_or_default(action: :list_rss_logs)
      return
    end

    # Save it so that we can keep it in the search bar in subsequent pages.
    session[:pattern] = pattern
    session[:search_type] = type

    ctrlr = search_ctrlr(type)
    pattern = synonym_pattern(pattern) if SYNONYM_PATTERN_TYPES.include?(type)

    if type == :google
      site_google_search(pattern)
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

  def site_google_search(pattern)
    if pattern.blank?
      redirect_to(action: :list_rss_logs)
    else
      search = URI.encode_www_form(q: "site:#{MO.domain} #{pattern}")
      redirect_to("https://google.com/search?#{search}")
    end
  end

  ##### Advanced Search #####

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
  rescue StandardError => err
    flash_error(err.to_s) if err.present?
    redirect_to(controller: "observer", action: "advanced_search_form")
  end

  ##############################################################################

  private

  def search_ctrlr(type)
    case type
    when :observation, :user
      :observer
    when :comment, :herbarium, :image, :location, :name,
      :project, :species_list, :herbarium_record
      type
    end
  end

  # Pattern can include variable(s) and value(s), e.g.: variable:value
  # If the pattern is a bare value, it defaults to synonym_of:"value"
  def synonym_pattern(pattern)
    return if pattern.blank? || variable_present?(pattern)

    pattern = %(synonym_of:"#{pattern}")
    session[:pattern] = pattern
  end

  def variable_present?(pattern)
    /\w+:/ =~ pattern
  end
end
