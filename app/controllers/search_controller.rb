# frozen_string_literal: true

# searches defined by the url query string
class SearchController < ApplicationController
  # This is the action the search bar commits to.  It just redirects to one of
  # several "foreign" search actions:
  #   /comments/index (params[:pattern])
  #   /glossary_terms/index (params[:pattern])
  #   /herbaria/index (params[:pattern])
  #   /herbarium_records/index (params[:pattern])
  #   /images/index (params[:pattern])
  #   /locations/index (params[:pattern])
  #   /names/index (params[:pattern])
  #   /observations/index (params[:pattern])
  #   /projects/index (params[:pattern])
  #   /species_lists/index (params[:pattern])
  #   /users/index (params[:pattern])
  #   /project/project_search
  #   /species_lists/index
  def pattern
    pattern = params.dig(:search, :pattern) { |p| p.to_s.strip_squeeze }
    type = params.dig(:search, :type)&.to_sym

    # Save it so that we can keep it in the search bar in subsequent pages.
    session[:pattern] = pattern
    session[:search_type] = type

    forward_pattern_search(type, pattern)
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
    query = create_query(model, query_params)
    redirect_to_model_controller(model, query)
  end

  ##############################################################################

  private

  def site_google_search(pattern)
    if pattern.blank?
      redirect_to("/")
    else
      search = URI.encode_www_form(q: "site:#{MO.domain} #{pattern}")
      redirect_to("https://google.com/search?#{search}")
    end
  end

  # In the case of "needs_naming", this is added to the search path params
  def forward_pattern_search(type, pattern)
    case type
    when :google
      site_google_search(pattern)
    when :comment, :glossary_term, :herbarium, :herbarium_record, :image,
         :location, :name, :observation, :project, :species_list, :user
      redirect_to_search_or_index(
        pattern: pattern,
        search_path: send(:"#{type.to_s.pluralize}_path",
                          params: { pattern: pattern }),
        index_path: send(:"#{type.to_s.pluralize}_path")
      )
    else
      flash_error(:runtime_invalid.t(type: :search, value: type.inspect))
      redirect_back_or_default("/")
    end
  end

  # NOTE: The autocompleters for name, location, and user all make the ids
  # available now, so this could be a lot more efficient.
  def add_filled_in_text_fields(query_params)
    [:content, :user_where, :name, :user].each do |field|
      val = params[:search][field].to_s
      next if val.blank?

      # Treat User field differently; remove angle-bracketed user name,
      # since it was included by the auto-completer only as a hint.
      val = user_login(params[:search]) if field == :user
      query_params[field] = val
    end
  end

  def user_login(params)
    if params.include?(:user_id)
      user = User.find_by(id: params[:user_id])
      return user.login if user
    end
    user = User.lookup_unique_text_name(params[:user])
    return user.login if user

    params[:user]
  end

  def add_applicable_filter_parameters(query_params, model)
    Query::Filter.by_model(model).each do |fltr|
      query_params[fltr.sym] = params.dig(:content_filter, fltr.sym)
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
    advanced_search_path = add_query_param({ controller: model.show_controller,
                                             action: :index,
                                             advanced_search: 1 },
                                           query)
    redirect_to(advanced_search_path)
  end
end
