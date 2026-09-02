# frozen_string_literal: true

#
#  = Searchable Concern
#
#  This is a module of reusable methods included by controllers that handle
#  "faceted" query searches per model, with separate inputs for each keyword.
#
################################################################################

module Searchable
  extend ActiveSupport::Concern

  # Maximum allowed total length of all search input fields
  MAX_SEARCH_INPUT_LENGTH = 8000

  # Maximum allowed length of the flat index-filter query string built
  # for the post-search redirect. Front-end proxies commonly reject an
  # overlong request line before it reaches Rails (nginx's compiled
  # default is 8KB total) -- a pasted multi-value field (e.g. Names)
  # can build a redirect URL well past that, which then shows up as a
  # broken page or a generic error instead of a useful message. Kept
  # well under 8KB to leave room for the rest of the request line and
  # for tighter limits at other layers (CDN, WAF). See issue #5276.
  MAX_INDEX_FILTER_URL_LENGTH = 4000

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
  # Lookup::Names DB hit for an obviously-pathological paste. See
  # issue #5276.
  MAX_NAME_LOOKUP_VALUES = 150

  included do
    def create
      redirect_to(action: :new) and return if clear_form?

      set_up_form_field_groupings # in case we need to re-render the form
      @query_params = params.require(search_object_name).permit(permittables)

      prepare_raw_params
      redirect_to(action: :new) and return if search_input_invalid?

      save_search_query_and_redirect_to_index
    end

    # Order matters: cheapest/most-actionable check first. A single
    # oversized field gets a field-specific message before falling
    # through to Query's validation errors or the generic aggregate-
    # length guard.
    def search_input_invalid?
      too_many_multiple_values? ||
        !validate_search_instance? ||
        index_filter_url_too_long?
    end

    def save_search_query_and_redirect_to_index
      save_search_query
      # always_index: 1 preserves MO's existing guarantee that a search
      # submission lands on the results list, not a same-request
      # auto-redirect to a single match -- see
      # ApplicationController::QueryParams#create_query_from_url_params.
      redirect_to(controller: "/#{search_type}", action: :index,
                  always_index: 1, **@query.index_filter)
    end

    def prepare_raw_params
      split_names_lookup_strings
      null_box_if_invalid
      null_region_if_overspecific_and_box_valid
      autocompleted_strings_to_ids
      resolve_fields_preferring_ids_to_ids
      range_fields_to_arrays
      parse_date_ranges
      normalize_notes_fields
    end

    # Used by search_helper to prefill nested params
    def nested_field_names
      nested_names_params + nested_in_box_params
    end

    # Default. Override in controllers
    def nested_names_params = []

    # e.g. "SpeciesLists"
    def module_name = self.class.name.deconstantize

    # e.g. :species_lists - Used by search_form
    def search_type = module_name.underscore.to_sym

    # e.g. :SpeciesList
    # Returns the capitalized :ModelSymbol used by Query for the type of query.
    def query_model = module_name.singularize.to_sym

    private

    def build_search_query
      return reset_search_query if params[:clear].present?

      find_or_create_query(query_model)
    end

    def reset_search_query
      session.delete(:names_preferences)
      create_query(query_model)
    end

    def turbo_stream_update
      turbo_stream.update(
        :search_nav_form,
        Components::Form::Search.new(
          @search,
          search_controller: self,
          context: :dropdown
        )
      )
    end

    def search_object_name = :"query_#{search_type}"

    def clear_form?
      if params[:commit] == :clear.ti
        clear_relevant_query
        return true
      end
      false
    end

    # The form has nested and temporary params, need to permit these.
    # Params that take arrays or hashes must be declared.
    def permittables
      ranges = fields_with_range.map { |field| :"#{field}_range" }
      ids = fields_preferring_ids.map { |field| :"#{field}_id" }
      names = { names: nested_names_params }
      in_box = { in_box: nested_in_box_params }
      perm = permitted_search_params + ranges + ids
      perm << names
      perm << in_box
      perm
    end

    def nested_in_box_params = [:north, :south, :east, :west].freeze

    def split_names_lookup_strings
      # If lookup is blank, remove the :names param for the query
      if (vals = @query_params.dig(:names, :lookup)).blank?
        @query_params[:names] = nil
        return
      end

      @query_params[:names][:lookup] = vals.split("\n").map(&:strip)
    end

    # Nested blank values will make for null query results,
    # so eliminate the whole :in_box param if it doesn't have values.
    def null_box_if_invalid
      return if valid_box?

      @query_params[:in_box] = nil
    end

    # A Google-looked-up region may not match a db value, so if it's longer
    # than 3 segments ("Alameda County, California, USA"), toss the region.
    def null_region_if_overspecific_and_box_valid
      return unless (region = @query_params[:region]) &&
                    valid_box? && region.split(",").length > 3

      @query_params[:region] = nil
    end

    def valid_box?
      return true if @query_params[:in_box].blank?

      ::Mappable::Box.new(**@query_params[:in_box]).valid?
    end

    # Check for `fields_preferring_ids` and swap these in if appropriate
    def autocompleted_strings_to_ids
      return unless respond_to?(:fields_preferring_ids)

      fields_preferring_ids.each do |key|
        next if @query_params[:"#{key}_id"].blank?

        @query_params[key] = @query_params[:"#{key}_id"].split(",")
        @query_params.delete(:"#{key}_id")
      end
    end

    # A field autocompleted_strings_to_ids left as raw text (no
    # matching client-side autocompleter match) breaks the post-search
    # redirect: QueryParams#resolve_record_backed_value treats a
    # single-value record-backed field as a strict id-only lookup, no
    # name fallback. Already-resolved ids pass through Lookup
    # unchanged, so this is safe to run on every search.
    def resolve_fields_preferring_ids_to_ids
      fields_preferring_ids.each do |field|
        next if @query_params[field].blank?

        klass = lookup_class_for(field)
        @query_params[field] = klass.new(@query_params[field]).ids.
                               map(&:to_s)
      end
    end

    def lookup_class_for(field)
      query_class = "Query::#{query_model.to_s.pluralize}".constantize
      accepts = query_class.attribute_types[field]&.accepts
      model = accepts.is_a?(Array) ? accepts.first : accepts
      "Lookup::#{model.name.pluralize}".constantize
    end

    # Check for `fields_with_range`, and join them into array if range present.
    # Sorts values so the range is in correct order (min, max).
    def range_fields_to_arrays
      return unless respond_to?(:fields_with_range)

      fields_with_range.each do |key|
        next if @query_params[:"#{key}_range"].blank?

        range = [@query_params[key], @query_params[:"#{key}_range"]]
        @query_params[key] = sort_range_values(range)
        @query_params.delete(:"#{key}_range")
      end
    end

    # Sort range values so min comes first. Works for both numeric values
    # (confidence) and string values (rank) that have a defined order.
    # Filters out blank values before sorting to avoid validation errors.
    def sort_range_values(range)
      # Filter out blank values before sorting
      non_blank = range.compact_blank
      return [] if non_blank.empty?
      return non_blank if non_blank.size == 1

      sort_rank_range(non_blank) || sort_numeric_range(non_blank)
    end

    def sort_rank_range(range)
      str_range = range.map(&:to_s)
      return unless str_range.all? { |v| Name.all_ranks.include?(v) }

      str_range.sort_by { |v| Name.all_ranks.index(v) }
    end

    def sort_numeric_range(range)
      range.map(&:to_f).sort
    end

    def parse_date_ranges
      @unparsed_dates = []
      [:date, :created_at, :updated_at].each { |field| parse_date_range(field) }
    end

    # A date the parser doesn't understand must fail the search, not
    # silently broaden it -- dropping the nil here used to run the
    # query with the date filter quietly gone.
    def parse_date_range(field)
      return if (date = @query_params[field]).blank?

      parsed = ::DateRangeParser.new(date).range
      @unparsed_dates << date if parsed.nil?
      @query_params[field] = parsed
    end

    def dates_parseable?
      return true if @unparsed_dates.blank?

      @unparsed_dates.each do |value|
        flash_error(:search_term_date_unparseable.t(value: value))
      end
      false
    end

    # Note that this @search query instance is not the one that gets saved and
    # sent, this step is only for validation of the params and removing blanks.
    # NOTE: We can't call @query_params.compact_blank, because we need to
    # preserve `false` values.
    def validate_search_instance?
      return false unless dates_parseable?

      @query_params.reject! { |_k, v| v == "" }
      @search = Query.create_query(query_model, @query_params)
      return true unless @search.invalid?

      messages = @search.validation_error_messages.compact_blank
      flash_error(*messages) if messages.present?
      false
    end

    # Guards against a single multi-value autocompleter field (Users,
    # Projects, ...) carrying more than MAX_MULTIPLE_VALUES pasted
    # values. Runs on the raw (pre-Query) params, before
    # validate_search_instance?, so it can name the offending field.
    # The Names lookup field is checked separately -- see
    # too_many_names_lookup_values?.
    def too_many_multiple_values?
      fields_preferring_ids.each do |field|
        count = multiple_value_count(field)
        next if count <= Searchable::MAX_MULTIPLE_VALUES

        flash_too_many_values(field, count, Searchable::MAX_MULTIPLE_VALUES)
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
      return false if count <= Searchable::MAX_MULTIPLE_VALUES

      if count > Searchable::MAX_NAME_LOOKUP_VALUES
        flash_too_many_values(field, count, Searchable::MAX_NAME_LOOKUP_VALUES)
        return true
      end

      resolve_names_lookup_to_ids!
      false
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
      lookup = Lookup::Names.new(
        names[:lookup],
        include_synonyms: names[:include_synonyms],
        include_subtaxa: names[:include_subtaxa],
        include_immediate_subtaxa: names[:include_immediate_subtaxa],
        exclude_original_names: names[:exclude_original_names]
      )
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
      return :names.t.to_s if field.is_a?(Array)

      :"query_#{field}".l.humanize
    end

    # Guards against a redirect URL too long for a front-end proxy's
    # request-line limit -- see MAX_INDEX_FILTER_URL_LENGTH above.
    # Only called once `@search` (built in validate_search_instance?)
    # is known valid, so `index_filter` matches the redirect built
    # afterward.
    def index_filter_url_too_long?
      length = @search.index_filter.to_query.bytesize
      return false if length <= Searchable::MAX_INDEX_FILTER_URL_LENGTH

      flash_error(
        :runtime_search_string_too_long.t(
          max: Searchable::MAX_INDEX_FILTER_URL_LENGTH, length: length
        )
      )
      true
    end

    def clear_relevant_query
      clear_query_in_session
      return if (@query = find_query(query_model))&.params.blank?

      # Save a blank query. This resets the query for this model everywhere.
      @query = Query.lookup_and_save(query_model)
    end

    # Save the validated search params and send these to the index.
    def save_search_query
      @query = Query.lookup_and_save(query_model, **@search.params)
    end

    def fields_preferring_ids = []

    def fields_with_range = []

    # Convert spaces to underscores in notes field names.
    # "INat notes field\nOther Field" => ["INat_notes_field", "Other_Field"]
    def normalize_notes_fields
      return if (val = @query_params[:has_notes_fields]).blank?

      @query_params[:has_notes_fields] =
        val.split("\n").map { |f| f.strip.tr(" ", "_") }.compact_blank
    end
  end
end
