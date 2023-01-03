# frozen_string_literal: true

# searches defined by the url query string
class SearchController < ApplicationController
  # This is the action the search bar commits to.  It just redirects to one of
  # several "foreign" search actions:
  #   /comments/index (params[:pattern])
  #   /herbaria/index (params[:pattern])
  #   /herbarium_records/index (params[:pattern])
  #   /image/image_search
  #   /location/location_search
  #   /name/name_search
  #   /observations/index (params[:pattern])
  #   /users/index (params[:pattern])
  #   /project/project_search
  #   /species_lists/index
  # rubocop:disable Metrics/AbcSize
  def pattern
    pattern = param_lookup([:search, :pattern]) { |p| p.to_s.strip_squeeze }
    type = param_lookup([:search, :type], &:to_sym)

    # Save it so that we can keep it in the search bar in subsequent pages.
    session[:pattern] = pattern
    session[:search_type] = type

    special_params = type == :herbarium ? { flavor: :all } : {}

    case type
    when :google
      site_google_search(pattern)
      return
    when :comment, :herbarium, :herbarium_record, :observation, :user,
      :species_list
      redirect_to_search_or_index(
        pattern: pattern,
        search_path: send("#{type.to_s.pluralize}_path", pattern: pattern),
        index_path: send("#{type.to_s.pluralize}_path", special_params)
      )
      return
    when :image, :location, :name, :project
      ctrlr = type
    else
      flash_error(:runtime_invalid.t(type: :search, value: type.inspect))
      redirect_back_or_default("/")
      return
    end

    redirect_to_search_or_list(ctrlr, type, pattern)
  end
  # rubocop:enable Metrics/AbcSize

  def site_google_search(pattern)
    if pattern.blank?
      redirect_to("/")
    else
      search = URI.encode_www_form(q: "site:#{MO.domain} #{pattern}")
      redirect_to("https://google.com/search?#{search}")
    end
  end

  ADVANCED_SEARCHABLE_MODELS = [Image, Location, Name, Observation].freeze

  # Advanced search form.  When it posts it just redirects to one of several
  # "foreign" search actions:
  #   image/advanced_search
  #   location/advanced_search
  #   name/advanced_search
  #   observations/advanced_search
  def advanced
    @filter_defaults = users_content_filters || {}
    return if params[:search].blank?

    model = ADVANCED_SEARCHABLE_MODELS.
            find { |m| m.name.downcase == params[:search][:model] }
    query_params = {}
    add_filled_in_text_fields(query_params)
    add_applicable_filter_parameters(query_params, model)
    query = create_query(model, :advanced_search, query_params)
    redirect_to_model_controller(model, query)
  end

  def add_filled_in_text_fields(query_params)
    [:content, :location, :name, :user].each do |field|
      val = params[:search][field].to_s
      next if val.blank?

      # Treat User field differently; remove angle-bracketed user name,
      # since it was included by the auto-completer only as a hint.
      val = val.sub(/ <.*/, "") if field == :user
      query_params[field] = val
    end
  end

  def add_applicable_filter_parameters(query_params, model)
    ContentFilter.by_model(model).each do |fltr|
      query_params[fltr.sym] = params[:"content_filter_#{fltr.sym}"]
    end
  end

  ##############################################################################

  private

  def redirect_to_search_or_list(ctrlr, type, pattern)
    # If pattern is blank, this would devolve into a very expensive index.
    if pattern.blank?
      redirect_to(controller: ctrlr, action: "list_#{type.to_s.pluralize}")
    else
      redirect_to(controller: ctrlr, action: "#{type}_search", pattern: pattern)
    end
  end

  def redirect_to_search_or_index(search_path:, index_path:, pattern: nil)
    # If pattern is blank, this would devolve into a very expensive index.
    if pattern.blank?
      redirect_to(index_path)
    else
      redirect_to(search_path)
    end
  end

  def redirect_to_model_controller(model, query)
    if model.controller_normalized?
      redirect_to(add_query_param({ controller: model.show_controller,
                                    action: :index,
                                    advanced_search: 1 },
                                  query))
    else
      redirect_to(add_query_param({ controller: model.show_controller,
                                    action: :advanced_search },
                                  query))
    end
  end
end
