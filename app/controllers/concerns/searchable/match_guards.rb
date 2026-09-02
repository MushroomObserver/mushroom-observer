# frozen_string_literal: true

#
#  = Searchable::MatchGuards Concern
#
#  Guards a Searchable controller's raw search params against
#  pathologically large multi-value fields, and tracks/flashes any
#  pasted value that failed to match a record.
#
################################################################################

module Searchable::MatchGuards
  extend ActiveSupport::Concern

  # Maximum newline-separated values a single multi-value autocompleter
  # field (Users, Projects, ...) may submit before being rejected
  # outright. This does NOT by itself guarantee the redirect URL stays
  # under MAX_INDEX_FILTER_URL_LENGTH, and there's no per-entry length
  # cap -- this check exists for the common case instead: a
  # field-specific message ("Users: too many values") is far more
  # actionable than the generic aggregate-length one when one field is
  # the problem. MAX_INDEX_FILTER_URL_LENGTH stays the unconditional
  # backstop. A Names lookup is handled separately above this count --
  # see MAX_NAME_LOOKUP_VALUES.
  MAX_MULTIPLE_VALUES = 50

  # Above MAX_MULTIPLE_VALUES, a Names lookup is resolved to ids
  # server-side instead of being rejected -- ids are far more compact
  # than name text (Name's max id is 6 digits in production;
  # Name.search_name ranges up to 133 characters, 99.9th percentile
  # 97), so this raises the practical ceiling before
  # MAX_INDEX_FILTER_URL_LENGTH forces a reject. Above this count,
  # reject outright rather than resolving, to avoid a large
  # Lookup::Names DB hit for an obviously-pathological paste.
  MAX_NAME_LOOKUP_VALUES = 150

  # Unmatched entries listed by name in the "didn't match" warning
  # before falling back to "... and N more".
  MAX_UNMATCHED_VALUES_DISPLAYED = 10

  # Length each displayed unmatched entry is truncated to. A paste
  # with no newlines (values separated by commas/tabs/spaces instead)
  # becomes one long "unmatched" entry -- unbounded, since nothing
  # limits an individual line's length before it reaches here. session
  # is cookie-backed, so embedding it whole risks CookieOverflow.
  MAX_UNMATCHED_VALUE_LENGTH = 50

  included do
    private

    # Guards against a single multi-value autocompleter field (Users,
    # Projects, ...) carrying more than MAX_MULTIPLE_VALUES pasted
    # values. Runs on the raw (pre-Query) params, before
    # validate_search_instance?, so it can name the offending field.
    # The Names lookup field is checked separately -- see
    # too_many_names_lookup_values?.
    def too_many_multiple_values?
      fields_preferring_ids.each do |field|
        count = multiple_value_count(field)
        next if count <= MAX_MULTIPLE_VALUES

        flash_too_many_values(field, count, MAX_MULTIPLE_VALUES)
        return true
      end
      too_many_names_lookup_values?
    end

    # Above MAX_MULTIPLE_VALUES, resolve the Names lookup to ids
    # instead of rejecting outright (see MAX_NAME_LOOKUP_VALUES).
    # Above MAX_NAME_LOOKUP_VALUES, reject without resolving. At or
    # under MAX_MULTIPLE_VALUES, the raw text stays as-is, but is
    # still checked for unmatched entries either way.
    def too_many_names_lookup_values?
      return false unless nested_names_params.include?(:lookup)

      field = [:names, :lookup]
      count = multiple_value_count(field)
      return false if count.zero?

      if count > MAX_NAME_LOOKUP_VALUES
        flash_too_many_values(field, count, MAX_NAME_LOOKUP_VALUES)
        return true
      end

      check_names_lookup_matches(count)
      false
    end

    # Below MAX_MULTIPLE_VALUES the raw text stays as-is (still short
    # enough to be readable in the URL) -- original_names is still
    # called, just to find which entries didn't match anything.
    # original_names stops after the first resolution pass, skipping
    # the synonym/subtaxa expansion .ids would trigger (expensive, and
    # unneeded here since unmatched is already populated by that
    # point).
    def check_names_lookup_matches(count)
      names = @query_params[:names]
      lookup = build_names_lookup(names)
      if count > MAX_MULTIPLE_VALUES
        resolve_names_lookup_to_ids!(names, lookup)
      else
        lookup.original_names
      end
      record_unmatched([:names, :lookup], lookup.unmatched)
    end

    # The names modifier selects submit literal "true"/"false" strings
    # (Components::Form::NamesLookupFieldGroup) -- any non-nil String
    # is truthy in Ruby, so "false" would otherwise be read as true.
    def modifier_true?(value)
      value.to_s.to_boolean == true
    end

    def build_names_lookup(names)
      Lookup::Names.new(
        names[:lookup],
        include_synonyms: modifier_true?(names[:include_synonyms]),
        include_subtaxa: modifier_true?(names[:include_subtaxa]),
        include_immediate_subtaxa:
          modifier_true?(names[:include_immediate_subtaxa]),
        exclude_original_names:
          modifier_true?(names[:exclude_original_names])
      )
    end

    # Swaps the pasted name strings for their resolved Name ids -- ids
    # are far shorter than name text. Resets the expansion-related
    # modifier flags to false: they're already baked into the
    # resolved id list, and leaving them set would re-run
    # synonym/subtaxa expansion a second time on the already-expanded
    # set -- the same hazard flagged in the comment on
    # Lookup::Names#lookup_ids for a single pass.
    # include_all_name_proposals/exclude_consensus are left untouched:
    # they control the Observation<->Naming join, not name resolution.
    def resolve_names_lookup_to_ids!(names, lookup)
      names[:lookup] = lookup.ids.map(&:to_s)
      names[:include_synonyms] = false
      names[:include_subtaxa] = false
      names[:include_immediate_subtaxa] = false
      names[:exclude_original_names] = false
    end

    def flash_too_many_values(field, count, max)
      flash_error(
        :runtime_search_too_many_values.t(
          field: multiple_value_field_label(field), count: count, max: max
        )
      )
    end

    # Dedup here, once, so the flashed count and list stay in sync --
    # a repeated typo shouldn't inflate the "N value(s) didn't match"
    # count or fill the truncated list with copies of itself.
    def record_unmatched(field, unmatched_vals)
      return if unmatched_vals.blank?

      (@unmatched_lookups ||= []) << [field, unmatched_vals.uniq]
    end

    # One flash_warning call, so multiple fields with misses land as
    # separate paragraphs in a single flash box instead of one box per
    # field.
    def flash_unmatched_lookups
      return if @unmatched_lookups.blank?

      messages = @unmatched_lookups.map do |field, vals|
        :runtime_search_unmatched_values.t(
          field: multiple_value_field_label(field), count: vals.length,
          list: truncated_unmatched_list(vals)
        )
      end
      flash_warning(*messages)
    end

    def truncated_unmatched_list(vals)
      shown = vals.first(MAX_UNMATCHED_VALUES_DISPLAYED).map do |val|
        truncate_unmatched_value(val)
      end
      return shown.join(", ") if shown.length == vals.length

      "#{shown.join(", ")}, and #{vals.length - shown.length} more"
    end

    def truncate_unmatched_value(val)
      return val if val.length <= MAX_UNMATCHED_VALUE_LENGTH

      "#{val[0, MAX_UNMATCHED_VALUE_LENGTH]}..."
    end

    def multiple_value_count(field)
      value =
        field.is_a?(Array) ? @query_params.dig(*field) : @query_params[field]
      return 0 if value.blank?
      return value.compact_blank.length if value.is_a?(Array)

      value.to_s.split("\n").compact_blank.length
    end

    def multiple_value_field_label(field)
      field.is_a?(Array) ? :names.t.to_s : :"query_#{field}".l.humanize
    end
  end
end
