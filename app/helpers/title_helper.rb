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
      tag.div(id: "filters", data: { controller: "filter-caption" }) do
        concat(caption_truncated(query))
        concat(caption_full(query))
      end
    end
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

  def caption_truncated(query)
    tag.div(class: "position-relative pr-3", id: "caption-truncated",
            data: { filter_caption_target: "truncated" }) do
      concat(caption_toggle_button(true))
      concat(caption_params(query, true))
    end
  end

  def caption_full(query)
    tag.div(class: "position-relative pr-3 d-none", id: "caption-full",
            data: { filter_caption_target: "full" }) do
      concat(caption_toggle_button(false))
      concat(caption_params(query, false))
    end
  end

  def caption_toggle_button(truncate)
    if truncate
      action = "showFull"
      direction = "down"
    else
      action = "showTruncated"
      direction = "up"
    end
    js_button(class: "top-right btn-link close",
              data: { filter_caption_target: action,
                      action: "filter-caption##{action}" }) do
      tag.span(class: "glyphicon glyphicon-chevron-#{direction}",
               aria: { hidden: true })
    end
  end

  def caption_params(query, truncate)
    tag.div(class: "small") do
      query.params.except(:by).compact_blank.each do |key, val|
        caption_one_filter_param(query, key, val, truncate:)
      end
    end
  end

  # Each param could be a boolean, a val, a set of vals,
  # a nested param with new key/vals, or a subquery.
  def caption_one_filter_param(query, key, val, truncate: false)
    concat(tag.div do
      if key.to_s.include?("_query")
        caption_subquery(query, key, val, truncate)
      elsif val.is_a?(Hash)
        caption_grouped_params(query, key, val, truncate)
      else
        caption_plain_param(query, key, val, truncate)
      end
    end)
  end

  # In the case of subqueries, treat them like a new query string.
  # Subquery params get { curly brackets }. The new query block is
  # inside the brackets and indented.
  def caption_subquery(query, label, hash, truncate)
    concat(tag.div("#{:"query_#{label}".l}: {"))
    concat(tag.div(class: "ml-3") do
      hash.each do |key, val|
        caption_one_filter_param(query, key, val, truncate:)
      end
    end)
    concat(tag.div("}"))
  end

  # In the case of nested params, print them on one line separated by comma.
  def caption_grouped_params(query, label, hash, truncate)
    len = hash.compact_blank.keys.size
    return if len.zero?

    concat(tag.span("#{:"query_#{label}".l}: "))
    if label == :target
      val = lookup_comment_target_val(hash)
      concat(tag.span(val))
    else
      caption_nested_params(query, hash, len, truncate)
    end
  end

  def caption_nested_params(query, hash, len, truncate)
    hash.compact_blank.each_with_index do |(key, val), idx|
      caption_plain_param(query, key, val, truncate)
      concat(tag.span(", ")) if idx < len - 1
    end
  end

  def caption_plain_param(query, key, val, truncate)
    label = :"query_#{key}".l
    # Just print the label for booleans (no `true`)
    if val == true
      concat(tag.span(label))
    else
      concat(tag.span("#{label}: ")) unless CAPTION_IGNORE_KEYS.include?(key)
      val = lookup_text_val(query, key, val, truncate)
      concat(tag.b(val))
    end
  end

  # The following params store IDs, but the captions are more legible
  # if they print a relevant "name" or "title" of the record.
  # This indexes which Lookup class to use to get the record:
  PARAM_LOOKUPS = {
    external_sites: :ExternalSites,
    field_slips: :FieldSlips,
    herbaria: :Herbaria,
    locations: :Locations,
    names: :Names,
    lookup: :Names,
    clade: :Names,
    projects: :Projects,
    project_lists: :ProjectSpeciesLists,
    species_lists: :SpeciesLists,
    by_users: :Users,
    for_user: :Users,
    by_author: :Users,
    by_editor: :Users,
    collectors: :Users,
    members: :Users
  }.freeze
  # The captions with these sub-params make more sense without the keys:
  CAPTION_IGNORE_KEYS = [:lookup, :id, :type].freeze
  # Max number of values to display if truncated:
  CAPTION_TRUNCATE = 3

  # Tries to get a proper name for the comment target.
  def lookup_comment_target_val(hash)
    type, id = hash.values_at(:type, :id)
    return unless type && id

    lookup = "Lookup::#{type.pluralize}".constantize
    lookup.new(id).titles.first
  end

  # NOTE: Can respond to special methods for certain keys.
  # Defaults to using the lookup method defined in CAPTIONABLE_QUERY_PARAMS
  def lookup_text_val(query, key, val, truncate)
    return param_val_itself(val, truncate) unless PARAM_LOOKUPS.key?(key)

    # Allow overrides (second param `true` means check for private methods)
    if [:names, :lookup].include?(key)
      tag.i(lookup_strings(query, key, truncate))
    else
      lookup_strings(query, key, truncate)
    end
  end

  # For values that aren't ids
  def param_val_itself(val, truncate)
    if val.is_a?(Array)
      val = val.first(CAPTION_TRUNCATE) if truncate
      val = val.join(", ")
    end
    val
  end

  # The max number of named items is hardcoded here to 3.
  def lookup_strings(query, param, truncate)
    ids = query.params.deep_find(param)
    lookups = if truncate
                ids.first(CAPTION_TRUNCATE)
              else
                ids
              end
    lookup_class = "Lookup::#{PARAM_LOOKUPS[param]}".constantize
    joined_vals = lookup_class.new(lookups).titles.join(", ")
    return joined_vals unless truncate

    truncate_joined_string(joined_vals, ids)
  end

  def truncate_joined_string(joined_vals, ids)
    if joined_vals.length > 100
      joined_vals = "#{joined_vals[0...97]}..."
    elsif ids.length > CAPTION_TRUNCATE
      joined_vals += ", ..."
    end
    joined_vals
  end
end
