# frozen_string_literal: true

class Query::Caption
  include ::ActionView::Helpers::TagHelper
  include ::ActionView::Helpers::TextHelper

  attr_accessor :query, :params

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
  # These make more sense without the keys
  IGNORE_KEYS = [:lookup, :id, :type].freeze
  # Truncated number of vals per param
  TRUNCATE_MAX = 3

  def initialize(query)
    @query = query
    @params = query.params.except(:by).compact_blank
  end

  def caption_truncated
    html = ""
    @params.each do |key, val|
      html += caption_one_filter_param(key, val, truncate: true)
    end
    html
  end

  def caption_full
    html = ""
    @params.each do |key, val|
      html += caption_one_filter_param(key, val, truncate: false)
    end
    html
  end

  private

  # rubocop:disable Rails/OutputSafety
  # These values come from the db and should be safe.

  # Each param could be a boolean, a val, a set of vals,
  # a nested param with new key/vals, or a subquery.
  def caption_one_filter_param(key, val, truncate: false)
    tag.div do
      if key.to_s.include?("_query")
        caption_subquery(key, val, truncate).html_safe
      elsif val.is_a?(Hash)
        caption_grouped_params(key, val, truncate).html_safe
      else
        caption_plain_param(key, val, truncate).html_safe
      end
    end
  end

  # In the case of subqueries, treat them like a new query string.
  # Subquery params get { curly brackets }. The new query block is
  # inside the brackets and indented.
  def caption_subquery(label, hash, truncate)
    html = tag.div("#{:"query_#{label}".l}: {")
    html += tag.div(class: "ml-3") do
      hash.each do |key, val|
        caption_one_filter_param(key, val, truncate).html_safe
      end
    end
    html += tag.div("}")
    html
  end

  # In the case of nested params, print them on one line separated by comma.
  def caption_grouped_params(label, hash, truncate)
    len = hash.compact_blank.keys.size
    return if len.zero?

    html = tag.span("#{:"query_#{label}".l}: ")
    if label == :target
      val = lookup_comment_target_val(hash).html_safe
      html += tag.span(val)
    else
      html += caption_nested_params(hash, len, truncate).html_safe
    end
    html
  end

  def caption_nested_params(hash, len, truncate)
    html = ""
    hash.compact_blank.each_with_index do |(key, val), idx|
      html += caption_plain_param(key, val, truncate).html_safe
      html += tag.span(", ") if idx < len - 1
    end
    html
  end

  def caption_plain_param(key, val, truncate)
    html = ""
    label = :"query_#{key}".l
    # Just print the label for booleans (no `true`)
    if val == true
      html += tag.span(label)
    else
      html += tag.span("#{label}: ") unless IGNORE_KEYS.include?(key)
      val = lookup_text_val(key, val, truncate).html_safe
      html += tag.b(val)
    end
    html
  end
  # rubocop:enable Rails/OutputSafety

  # Tries to get a proper name for the comment target.
  def lookup_comment_target_val(hash)
    type, id = hash.values_at(:type, :id)
    return unless type && id

    lookup = "Lookup::#{type.pluralize}".constantize
    lookup.new(id).titles.first
  end

  # NOTE: Can respond to special methods for certain keys.
  # Defaults to using the lookup method defined in PARAM_LOOKUPS
  def lookup_text_val(key, val, truncate)
    return param_val_itself(val, truncate) unless PARAM_LOOKUPS.key?(key)

    # Allow overrides (second param `true` means check for private methods)
    if respond_to?(:"caption_#{key}", true)
      send(:"caption_#{key}", truncate)
    else
      lookup_strings(key, truncate)
    end
  end

  # For values that aren't ids
  def param_val_itself(val, truncate)
    if val.is_a?(Array)
      val = val.first(TRUNCATE_MAX) if truncate
      val = val.join(", ")
    end
    val
  end

  # Override: Italicize names returned by the lookup
  def caption_names(truncate)
    tag.i(lookup_strings(:names, truncate))
  end

  def caption_lookup(truncate)
    tag.i(lookup_strings(:lookup, truncate))
  end

  # The max number of named items is hardcoded here to 3.
  def lookup_strings(param, truncate)
    ids = @params.deep_find(param)
    lookups = if truncate
                ids.first(TRUNCATE_MAX)
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
    elsif ids.length > TRUNCATE_MAX
      joined_vals += ", ..."
    end
    joined_vals
  end
end
