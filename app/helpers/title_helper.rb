# frozen_string_literal: true

# --------- Contextual Page Title -----------------------------
#
#  add_page_title(title)        # add content_for(:title)
#                                 and content_for(:document_title)
#  add_owner_naming(naming)     # add content_for(:owner_naming), on show obs
#  title_tag_contents           # text to put in html header <title>
#  add_index_title              # logic for index titles, with fallbacks
#  index_default_title          # logic for observations index default sort
#  add_query_filters(query)     # content_for(:filters)
#                                 builds filter caption explaining
#                                 index results, if filtered
#
module TitleHelper
  # sets both the html doc title and the title for the page (previously @title)
  def add_page_title(title)
    content_for(:title) do
      title
    end
    content_for(:document_title) do
      title_tag_contents(title)
    end
  end

  # Show obs: observer's preferred naming. HTML here in case there is no naming
  def add_owner_naming(naming)
    return unless naming

    content_for(:owner_naming) do
      tag.h5(naming, id: "owner_naming")
    end
  end

  # contents of the <title> in html <head>
  def title_tag_contents(title, action: controller.action_name)
    if title.present?
      title.strip_html.unescape_html # removes tags and special chars
    elsif TranslationString.where(tag: "title_for_#{action}").present?
      :"title_for_#{action}".t
    else
      action.tr("_", " ").titleize
    end
  end

  # Simple builder for index page titles,
  # with a complex builder for the "filter caption" that explains the query.
  def add_index_title(query, map: false)
    title = if map
              :map_locations_title.l(
                locations: query.model.table_name.upcase.to_sym.l
              )
            elsif query
              query.model.table_name.upcase.to_sym.l
            else
              ""
            end
    add_page_title(title)
    add_query_filters(query)
  end

  def add_query_filters(query)
    return unless query&.params

    content_for(:filters) do
      tag.div(class: "small", id: "filters") do
        query.params.except(:by).compact_blank.each do |key, val|
          caption_one_filter_param(query, key, val)
        end
      end
    end
  end

  # Each param could be a boolean, a val, a set of vals,
  # a nested param with new key/vals, or a subquery.
  def caption_one_filter_param(query, key, val)
    concat(tag.div do
      if key.to_s.include?("_query")
        caption_string_for_subquery(query, key, val)
      elsif val.is_a?(Hash)
        caption_string_for_nested_params(query, key, val)
      else
        caption_string_for_val(query, key, val)
      end
    end)
  end

  # In the case of subqueries, treat them like a new query string.
  # Subquery params get { curly brackets }. The new query block is
  # inside the brackets and indented.
  def caption_string_for_subquery(query, label, hash)
    concat(tag.div("#{:"query_#{label}".l}: {"))
    concat(tag.div(class: "ml-3") do
      hash.each do |key, val|
        caption_one_filter_param(query, key, val)
      end
    end)
    concat(tag.div("}"))
  end

  # In the case of nested params, print them on one line separated by comma.
  # Nested params get [square brackets]
  def caption_string_for_nested_params(query, label, hash)
    len = hash.compact_blank.keys.size
    return if len.zero?

    concat(tag.span("#{:"query_#{label}".l}: "))
    if label == :target
      val = caption_lookup_comment_target_val(hash)
      concat(tag.span(val))
    else
      caption_val_for_nested_params(query, hash, len)
    end
  end

  def caption_val_for_nested_params(query, hash, len)
    hash.compact_blank.each_with_index do |(key, val), idx|
      caption_string_for_val(query, key, val)
      concat(tag.span(", ")) if idx < len - 1
    end
  end

  # These make more sense without the keys
  CAPTION_IGNORE_KEYS = [:lookup, :id, :type].freeze

  CAPTIONABLE_QUERY_PARAMS = {
    herbaria: Herbarium,
    locations: Location,
    names: Name,
    projects: Project,
    project_lists: Project,
    species_lists: SpeciesList,
    by_users: User,
    for_user: User,
    by_author: User,
    by_editor: User,
    search_user: User,
    lookup: Name
  }.freeze

  CAPTION_LOOKUPS = {
    Herbarium: :name,
    Location: :display_name,
    Name: :text_name,
    Observation: :unique_text_name,
    Project: :title,
    SpeciesList: :title,
    User: :login
  }.freeze

  def caption_string_for_val(query, key, val)
    translation = :"query_#{key}".l
    if val == true
      concat(tag.span(translation))
    else
      unless CAPTION_IGNORE_KEYS.include?(key)
        concat(tag.span("#{translation}: "))
      end
      val = caption_lookup_text_val(query, key, val)
      concat(tag.b(val))
    end
  end

  # Tries to get a proper name for the comment target.
  def caption_lookup_comment_target_val(hash)
    type, id = hash.values_at(:type, :id)
    return unless type && id

    method = CAPTION_LOOKUPS[type.to_sym]
    get_attribute_of_instance_by_integer(id, type.to_s.constantize, method)
  end

  # NOTE: Can respond to special methods for certain keys.
  # Defaults to using the lookup method defined in CAPTIONABLE_QUERY_PARAMS
  def caption_lookup_text_val(query, key, val)
    unless CAPTIONABLE_QUERY_PARAMS.key?(key)
      val = val.join(", ") if val.is_a?(Array)
      return val
    end

    key = :names if key == :lookup
    if respond_to?(:"caption_#{key}")
      send(:"caption_#{key}", query)
    else
      map_join_and_truncate(query, key)
    end
  end

  # def caption_herbaria(query)
  #   map_join_and_truncate(query, :herbaria)
  # end

  # NOTE: used in "Locations with Observations of {name}" - AN 2023
  # def caption_locations(query)
  #   map_join_and_truncate(query, :locations)
  # end

  def caption_names(query)
    tag.i(map_join_and_truncate(query, :lookup))
  end

  # def caption_projects(query)
  #   map_join_and_truncate(query, :projects)
  # end

  # def caption_project_lists(query)
  #   map_join_and_truncate(query, :project_lists)
  # end

  # def caption_species_lists(query)
  #   map_join_and_truncate(query, :species_lists)
  # end

  def caption_by_users(query)
    caption_user_legal_name_or_list_of_logins(query, :by_users)
  end

  def caption_for_user(query)
    caption_user_legal_name_or_list_of_logins(query, :for_user)
  end

  def caption_by_editor(query)
    caption_user_legal_name_or_list_of_logins(query, :by_editor)
  end

  def caption_by_author(query)
    caption_user_legal_name_or_list_of_logins(query, :by_author)
  end

  def caption_user_legal_name_or_list_of_logins(query, key)
    if query.params.deep_find(key).size == 1
      User.find(query.params.deep_find(key).first).legal_name
    else
      map_join_and_truncate(query, key)
    end
  end

  # takes a search string
  def caption_search_user(query)
    query.params.deep_find(:search_user)
  end

  # The max number of named items is hardcoded here to 3.
  def map_join_and_truncate(query, param)
    model, method = caption_lookup_model_and_method(param)
    str = query.params.deep_find(param)[0..2].map do |val|
      # Integer(val) throws ArgumentError if val is not an integer.
      str = get_attribute_of_instance_by_integer(val, model, method)
    rescue ArgumentError # rubocop:disable Layout/RescueEnsureAlignment
      val
    end.join(", ")
    if str.length > 100
      str = "#{str[0...97]}..."
    elsif query.params.deep_find(param).length > 3
      str += ", ..."
    end
    str
  end

  def caption_lookup_model_and_method(param)
    model = CAPTIONABLE_QUERY_PARAMS[param]
    method = CAPTION_LOOKUPS[model.name.to_sym]
    [model, method]
  end

  def get_attribute_of_instance_by_integer(val, model, method)
    val = val.min if val.is_a?(Array)
    return val if val.is_a?(AbstractModel)

    model.find(Integer(val)).send(method)
  end

  # Used by several indexes that can be filtered based on user prefs
  def add_filter_help(filters_applied)
    return unless filters_applied

    content_for(:filter_help) do
      help_tooltip(
        "(#{:filtered.t})",
        title: :rss_filtered_mouseover.t, class: "filter-help"
      )
    end
  end
end
