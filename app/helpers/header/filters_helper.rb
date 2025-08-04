# frozen_string_literal: true

# --------- Index Filters -----------------------------
#
#  add_query_filters(query)         # content_for(:filters)
#                                     builds filter caption explaining
#                                     index results, if filtered
#  add_filter_help(filters_applied) # content_for(:filter_help)
#
module Header
  module FiltersHelper
    def add_query_filters(query)
      return unless query&.params

      content_for(:filters) do
        query_filters(query)
      end
    end

    def query_filters(query)
      tag.div(id: "filters",
              data: { controller: "filter-caption",
                      query_params: query.params.to_json,
                      query_record: query.record.id,
                      query_alph: query.record.id.alphabetize }) do
        concat(filter_caption_truncated(query))
        concat(filter_caption_full(query))
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

    def filter_caption_truncated(query)
      tag.div(class: "position-relative pr-3 collapse in",
              id: "caption-truncated",
              data: { filter_caption_target: "truncated" }) do
        concat(filter_caption_toggle_button(true))
        concat(filter_caption_params(query, true))
      end
    end

    def filter_caption_full(query)
      tag.div(class: "position-relative pr-3 collapse", id: "caption-full",
              data: { filter_caption_target: "full" }) do
        concat(filter_caption_toggle_button(false))
        concat(filter_caption_params(query, false))
      end
    end

    def filter_caption_toggle_button(truncate)
      if truncate
        action = "showFull"
        direction = "down"
      else
        action = "showTruncated"
        direction = "up"
      end
      js_button(class: "top-right btn-link toggle",
                data: { filter_caption_target: action,
                        action: "filter-caption##{action}" }) do
        tag.span(class: "glyphicon glyphicon-chevron-#{direction}",
                 aria: { hidden: true })
      end
    end

    def filter_caption_params(query, truncate)
      tag.div(class: "small") do
        filter_caption_param_text(query, truncate)
      end
    end

    def filter_caption_param_text(query, truncate)
      if query.params.except(:order_by).present?
        query.params.except(:order_by).compact_blank.each do |key, val|
          filter_caption_one_param(query, key, val, truncate:)
        end
      else
        :ALL.l
      end
    end

    # Each param could be a boolean, a val, a set of vals,
    # a nested param with new key/vals, or a subquery.
    def filter_caption_one_param(query, key, val, truncate: false, tag: :div)
      concat(content_tag(tag) do
        if key.to_s.include?("_query")
          filter_caption_subquery(query, key, val, truncate)
        elsif val.is_a?(Hash)
          filter_caption_grouped_params(query, key, val, truncate)
        else
          filter_caption_plain_param(query, key, val, truncate)
        end
      end)
    end

    # In the case of subqueries, treat them like a new query string.
    # Subquery params get { curly brackets }. The new query block is
    # inside the brackets and indented.
    def filter_caption_subquery(query, label, hash, truncate)
      concat(tag.span("#{:"query_#{label}".l}: [ "))
      hash.except(:order_by).each do |key, val|
        filter_caption_one_param(query, key, val, truncate:, tag: :span)
      end
      concat(tag.span(" ] "))
    end

    # In the case of nested params, print them on one line separated by comma.
    def filter_caption_grouped_params(query, label, hash, truncate)
      len = hash.compact_blank.keys.size
      return if len.zero?

      concat(tag.span("#{:"query_#{label}".l}: "))
      if label == :target
        val = filter_lookup_comment_target_val(hash)
        concat(tag.span(val))
      else
        filter_caption_nested_params(query, hash, len, truncate)
      end
    end

    def filter_caption_nested_params(query, hash, len, truncate)
      hash.compact_blank.each_with_index do |(key, val), idx|
        filter_caption_plain_param(query, key, val, truncate)
        concat(tag.span(", ")) if idx < len - 1
      end
    end

    def filter_caption_plain_param(query, key, val, truncate)
      label = :"query_#{key}".l
      # Just print the label for booleans (no `true`)
      if val == true
        concat(tag.span(label))
      else
        concat(tag.span("#{label}: ")) unless CAPTION_IGNORE_KEYS.include?(key)
        val = filter_lookup_text_val(query, key, val, truncate)
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
    CAPTION_IGNORE_KEYS = [:lookup, :id].freeze
    # Max number of values to display if truncated:
    CAPTION_TRUNCATE = 3

    # Tries to get a proper name for the comment target.
    def filter_lookup_comment_target_val(hash)
      type, id = hash.values_at(:type, :id)
      return unless type && id

      lookup = "Lookup::#{type.pluralize}".constantize
      lookup.new(id).titles.first
    end

    # NOTE: Can respond to special methods for certain keys.
    # Defaults to using the lookup method defined in CAPTIONABLE_QUERY_PARAMS
    def filter_lookup_text_val(query, key, val, truncate)
      return param_val_itself(key, val, truncate) unless PARAM_LOOKUPS.key?(key)

      # Allow overrides (second param `true` means check for private methods)
      if [:names, :lookup].include?(key)
        tag.i(filter_lookup_strings(query, key, truncate))
      else
        filter_lookup_strings(query, key, truncate)
      end
    end

    # For values that aren't ids, just join and maybe truncate
    def param_val_itself(key, val, truncate)
      if key == :type # lowercase strings joined by spaces
        val = val.titleize.split.join(", ")
      elsif val.is_a?(Array)
        val = val.first(CAPTION_TRUNCATE) if truncate
        val = val.join(", ")
        val += ", ..." if truncate && val.length > CAPTION_TRUNCATE
      end
      val
    end

    # The max number of named items is hardcoded here to 3.
    def filter_lookup_strings(query, param, truncate)
      ids = query.params.deep_find(param)
      lookups = if truncate
                  ids.first(CAPTION_TRUNCATE)
                else
                  ids
                end
      subclass = PARAM_LOOKUPS[param]
      lookup = "Lookup::#{subclass}".constantize
      joined_vals = lookup.new(lookups, include_misspellings: false).
                    titles.join(", ")
      return joined_vals unless truncate

      filter_truncate_joined_string(joined_vals, ids)
    end

    def filter_truncate_joined_string(joined_vals, ids)
      if joined_vals.length > 100
        joined_vals = "#{joined_vals[0...97]}..."
      elsif ids.length > CAPTION_TRUNCATE
        joined_vals += ", ..."
      end
      joined_vals
    end
  end
end
