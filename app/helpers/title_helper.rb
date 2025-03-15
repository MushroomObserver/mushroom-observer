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
        caption_subquery(query, key, val)
      elsif val.is_a?(Hash)
        caption_grouped_params(query, key, val)
      else
        caption_plain_param(query, key, val)
      end
    end)
  end

  # In the case of subqueries, treat them like a new query string.
  # Subquery params get { curly brackets }. The new query block is
  # inside the brackets and indented.
  def caption_subquery(query, label, hash)
    concat(tag.div("#{:"query_#{label}".l}: {"))
    concat(tag.div(class: "ml-3") do
      hash.each do |key, val|
        caption_one_filter_param(query, key, val)
      end
    end)
    concat(tag.div("}"))
  end

  # In the case of nested params, print them on one line separated by comma.
  def caption_grouped_params(query, label, hash)
    len = hash.compact_blank.keys.size
    return if len.zero?

    concat(tag.span("#{:"query_#{label}".l}: "))
    if label == :target
      val = caption_lookup_comment_target_val(hash)
      concat(tag.span(val))
    else
      caption_nested_params(query, hash, len)
    end
  end

  # Tries to get a proper name for the comment target.
  def caption_lookup_comment_target_val(hash)
    type, id = hash.values_at(:type, :id)
    return unless type && id

    lookup = "Lookup::#{type.pluralize}".constantize
    lookup.new(id).titles.first
  end

  def caption_nested_params(query, hash, len)
    hash.compact_blank.each_with_index do |(key, val), idx|
      caption_plain_param(query, key, val)
      concat(tag.span(", ")) if idx < len - 1
    end
  end

  # These make more sense without the keys
  CAPTION_IGNORE_KEYS = [:lookup, :id, :type].freeze

  CAPTIONABLE_QUERY_PARAMS = {
    external_sites: :ExternalSites,
    field_slips: :FieldSlips,
    herbaria: :Herbaria,
    locations: :Locations,
    region: :Locations,
    names: :Names,
    clade: :Names,
    projects: :Projects,
    project_lists: :ProjectSpeciesLists,
    species_lists: :SpeciesLists,
    by_users: :Users,
    for_user: :Users,
    by_author: :Users,
    by_editor: :Users,
    collectors: :Users,
    members: :Users,
    lookup: :Names
  }.freeze

  def caption_plain_param(query, key, val)
    label = :"query_#{key}".l
    # Just print the label for booleans (no `true`)
    if val == true
      concat(tag.span(label))
    else
      concat(tag.span("#{label}: ")) unless CAPTION_IGNORE_KEYS.include?(key)
      val = caption_lookup_text_val(query, key, val)
      concat(tag.b(val))
    end
  end

  # NOTE: Can respond to special methods for certain keys.
  # Defaults to using the lookup method defined in CAPTIONABLE_QUERY_PARAMS
  def caption_lookup_text_val(query, key, val)
    unless CAPTIONABLE_QUERY_PARAMS.key?(key)
      val = val[0..2].join(", ") if val.is_a?(Array)
      return val
    end

    key = :names if key == :lookup
    if respond_to?(:"caption_#{key}")
      send(:"caption_#{key}", query)
    else
      caption_lookup_strings_and_truncate(query, key)
    end
  end

  # Italicize names
  def caption_names(query)
    tag.i(caption_lookup_strings_and_truncate(query, :lookup))
  end

  # takes a search string
  def caption_search_user(query)
    query.params.deep_find(:search_user)
  end

  # The max number of named items is hardcoded here to 3.
  def caption_lookup_strings_and_truncate(query, param)
    ids = query.params.deep_find(param)
    lookup = "Lookup::#{CAPTIONABLE_QUERY_PARAMS[param]}".constantize
    str = lookup.new(ids[0..2]).titles.join(", ")

    if str.length > 100
      str = "#{str[0...97]}..."
    elsif ids.length > 3
      str += ", ..."
    end
    str
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
