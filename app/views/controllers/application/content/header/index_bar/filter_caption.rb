# frozen_string_literal: true

# Phlex view that renders the filter-caption HTML for the index-bar.
# Wired up via `Header::FiltersHelper#add_query_filters(query)`, which
# stores `render(FilterCaption.new(query: query))` in
# `content_for(:filters)` so the layout's `IndexBar` can yield it on
# index actions.
#
# Owns the entire caption tree that used to live as ~270 lines of
# helper methods (`query_filters`, `filter_caption_truncated`,
# `filter_caption_full`, `filter_caption_toggle_button`,
# `filter_caption_params`, `filter_caption_param_text`,
# `filter_caption_params_joined`, `filter_caption_one_param`,
# `filter_caption_subquery`, `filter_caption_grouped_params`,
# `filter_caption_nested_params`, `filter_caption_plain_param`,
# plus the lookup string helpers and the four constants). The helper
# module now retains only `add_query_filters` (the public API the
# 80 index action templates call) and `type_tags_to_label` (covered
# by its own unit test).
module Views::Controllers::Application::Content
  class Header::IndexBar::FilterCaption < Views::Base
    # `type_tags_to_label` stays in `Header::FiltersHelper` so its
    # existing `Header::FiltersHelperTest` keeps covering the
    # SENTINEL_TYPE_TAGS branches; register it here to call via the
    # helper chain rather than duplicating the constant + method.
    register_value_helper :type_tags_to_label
    # The following params store IDs; the captions are more legible
    # if they print a relevant "name" or "title" of the record.
    # This indexes which `Lookup::<class>` to use.
    PARAM_LOOKUPS = {
      external_sites: :ExternalSites,
      field_slips: :FieldSlips,
      herbaria: :Herbaria,
      locations: :Locations,
      within_locations: :Locations,
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
    # The captions with these sub-params make more sense without keys:
    CAPTION_IGNORE_KEYS = [:lookup, :id].freeze
    # Max number of values to display if truncated:
    CAPTION_TRUNCATE = 3
    # Lookup keys whose joined string is italicized inside the `<b>`
    # tag (Latin / taxonomic names).
    ITALICIZE_LOOKUP_KEYS = [:names, :lookup].freeze

    prop :query, ::Query

    def view_template
      div(id: "filters", class: "position-relative pr-5",
          data: {
            controller: "filter-caption",
            query_params: @query.params.to_json,
            query_record: @query.record.id,
            query_alph: @query.record.id.alphabetize
          }) do
        render_collapse(truncate: true, klass: "collapse in",
                        id: "caption-truncated", target: "truncated")
        render_collapse(truncate: false, klass: "collapse",
                        id: "caption-full", target: "full")
      end
    end

    private

    def render_collapse(truncate:, klass:, id:, target:)
      div(class: klass, id: id,
          data: { filter_caption_target: target }) do
        render_toggle_button(truncate: truncate)
        render_caption_params(truncate: truncate)
      end
    end

    # Mirrors `js_button(class: …) { tag.span(…) }` from the helper:
    # `js_button` is `<button type="button" class="btn btn-default …">`,
    # with classes merged. Emit directly for clarity.
    def render_toggle_button(truncate:)
      action = truncate ? "showFull" : "showTruncated"
      direction = truncate ? "down" : "up"
      # `name="button"` matches Rails' `button_tag` default that
      # `js_button` inherits — preserves byte-equivalent HTML for the
      # parity test.
      button(
        type: "button",
        name: "button",
        class: class_names(
          %w[btn btn-default top-right btn-link toggle]
        ),
        data: { filter_caption_target: action,
                action: "filter-caption##{action}" }
      ) do
        # `aria-hidden="true"` as a string (not boolean) matches
        # Rails' `tag.span(aria: { hidden: true })` HTML output —
        # Phlex 2 renders a boolean `true` as the empty-string form.
        span(class: "glyphicon glyphicon-chevron-#{direction}",
             aria: { hidden: "true" })
      end
    end

    def render_caption_params(truncate:)
      div(class: "small") do
        render_caption_param_text(truncate: truncate)
      end
    end

    def render_caption_param_text(truncate:)
      if @query.params.except(:order_by).present?
        wrap_tag = truncate ? :span : :div
        render_params_joined(@query.params, truncate: truncate,
                                            wrap_tag: wrap_tag)
      else
        plain(:ALL.l)
      end
    end

    def render_params_joined(params_hash, truncate:, wrap_tag:)
      items = params_hash.except(:order_by).compact_blank
      if truncate
        render_truncated_items(items, wrap_tag: wrap_tag)
      else
        render_all_items(items, wrap_tag: wrap_tag)
      end
    end

    def render_truncated_items(items, wrap_tag:)
      visible = items.first(CAPTION_TRUNCATE)
      visible.each_with_index do |(key, val), idx|
        render_one_param(key, val, truncate: true, wrap_tag: wrap_tag)
        plain(", ") if idx < visible.length - 1
      end
      plain("…") if items.length > CAPTION_TRUNCATE
    end

    def render_all_items(items, wrap_tag:)
      joiner = wrap_tag == :span ? ", " : ""
      items.each_with_index do |(key, val), idx|
        render_one_param(key, val, truncate: false, wrap_tag: wrap_tag)
        plain(joiner) if joiner.present? && idx < items.length - 1
      end
    end

    # Each param could be a boolean, a value, a set of values, a
    # nested key/val Hash, or a subquery.
    def render_one_param(key, val, truncate:, wrap_tag:)
      send(wrap_tag) do
        if key.to_s.include?("_query")
          render_subquery(key, val, truncate: truncate)
        elsif val.is_a?(Hash)
          render_grouped_params(key, val, truncate: truncate)
        else
          render_plain_param(key, val, truncate: truncate)
        end
      end
    end

    # Subquery: `label: [ <nested params> ]` with span wrappers.
    def render_subquery(label, hash, truncate:)
      span { plain("#{:"query_#{label}".l}: [ ") }
      render_params_joined(hash, truncate: truncate, wrap_tag: :span)
      span { plain(" ] ") }
    end

    # Nested params on one line separated by comma. The `:target`
    # key gets a Lookup-driven single-string val rather than nested
    # iteration.
    def render_grouped_params(label, hash, truncate:)
      compact = hash.compact_blank
      return if compact.empty?

      span { plain("#{:"query_#{label}".l}: ") }
      if label == :target
        span { plain(lookup_comment_target_val(hash).to_s) }
      else
        render_nested_params(compact, truncate: truncate)
      end
    end

    def render_nested_params(compact, truncate:)
      compact.each_with_index do |(key, val), idx|
        render_plain_param(key, val, truncate: truncate)
        span { plain(", ") } if idx < compact.size - 1
      end
    end

    def render_plain_param(key, val, truncate:)
      label = :"query_#{key}".l
      if val == true
        span { plain(label) }
      else
        span { plain("#{label}: ") } unless CAPTION_IGNORE_KEYS.include?(key)
        b { render_lookup_text_val(key, val, truncate: truncate) }
      end
    end

    # Emits the value inside `<b>`. Italicizes when the lookup key
    # is `names` / `lookup` (taxonomic names render in italic).
    def render_lookup_text_val(key, val, truncate:)
      if key == :confidence
        plain(confidence_val_as_label(val))
      elsif !PARAM_LOOKUPS.key?(key)
        plain(param_val_itself(key, val, truncate: truncate))
      elsif ITALICIZE_LOOKUP_KEYS.include?(key)
        i { plain(filter_lookup_strings(key, truncate: truncate)) }
      else
        plain(filter_lookup_strings(key, truncate: truncate))
      end
    end

    # --- pure-string helpers (no HTML emission) -------------------

    # Tries to get a proper name for the comment target.
    def lookup_comment_target_val(hash)
      type, id = hash.values_at(:type, :id)
      return unless type && id

      lookup = "Lookup::#{type.pluralize}".constantize
      lookup.new(id).titles.first
    end

    # `Query::Observations` normalizes scalar `confidence: 2.0` into
    # the array form (`[2.0]`) at validation time, so the array
    # branch is always taken; no scalar fallback needed.
    def confidence_val_as_label(val)
      val.map { |v| Vote.confidence(v.to_f) }.join(" – ")
    end

    def param_val_itself(key, val, truncate:)
      if key == :type
        type_tags_to_label(val)
      elsif val.is_a?(Array)
        join_array_val(val, truncate: truncate)
      else
        val
      end
    end

    def join_array_val(val, truncate:)
      values = truncate ? val.first(CAPTION_TRUNCATE) : val
      string = values.join(", ")
      string += ", ..." if truncate && val.length > CAPTION_TRUNCATE
      string
    end

    # The max number of named items is hardcoded to 3.
    def filter_lookup_strings(param, truncate:)
      ids = @query.params.deep_find(param)
      lookups = truncate ? ids.first(CAPTION_TRUNCATE) : ids
      subclass = PARAM_LOOKUPS[param]
      lookup = "Lookup::#{subclass}".constantize
      # Use Set in case there are doubles (e.g. many Genus names).
      joined_vals = Set.new(
        lookup.new(lookups, include_misspellings: false).titles
      ).join(", ")
      return joined_vals unless truncate

      truncate_joined_string(joined_vals, ids)
    end

    def truncate_joined_string(joined_vals, ids)
      if joined_vals.length > 100
        "#{joined_vals[0...97]}..."
      elsif ids.length > CAPTION_TRUNCATE
        "#{joined_vals}, ..."
      else
        joined_vals
      end
    end
  end
end
