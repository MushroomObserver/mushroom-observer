# frozen_string_literal: true

#
#  = Searchable::MatchGuards Concern
#
#  Guards a Searchable controller's raw search params against
#  pathologically large multi-value fields.
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
    # Above MAX_NAME_LOOKUP_VALUES, reject without resolving.
    def too_many_names_lookup_values?
      return false unless nested_names_params.include?(:lookup)

      field = [:names, :lookup]
      count = multiple_value_count(field)
      return false if count <= MAX_MULTIPLE_VALUES

      if count > MAX_NAME_LOOKUP_VALUES
        flash_too_many_values(field, count, MAX_NAME_LOOKUP_VALUES)
        return true
      end

      resolve_names_lookup_to_ids!
      false
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

    # Swaps the pasted name strings in @query_params[:names][:lookup]
    # for their resolved Name ids -- ids are far shorter than name
    # text, and any entry that failed to match is dropped in the
    # process (see issue #5299 for surfacing that to the user).
    # Resets the expansion-related modifier flags to false: they're
    # already baked into the resolved id list, and leaving them set
    # would re-run synonym/subtaxa expansion a second time on the
    # already-expanded set -- the same hazard flagged in the comment
    # on Lookup::Names#lookup_ids for a single pass.
    # include_all_name_proposals/exclude_consensus are left untouched:
    # they control the Observation<->Naming join, not name resolution.
    def resolve_names_lookup_to_ids!
      names = @query_params[:names]
      lookup = build_names_lookup(names)
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

    def multiple_value_count(field)
      value =
        field.is_a?(Array) ? @query_params.dig(*field) : @query_params[field]
      return 0 if value.blank?
      return value.length if value.is_a?(Array)

      value.to_s.split("\n").compact_blank.length
    end

    def multiple_value_field_label(field)
      field.is_a?(Array) ? :names.t.to_s : :"query_#{field}".l.humanize
    end
  end
end
