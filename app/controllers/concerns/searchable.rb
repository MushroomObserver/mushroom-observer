# frozen_string_literal: true

#
#  = Searchable Concern
#
#  This is a module of reusable methods included by controllers that handle
#  "faceted" query searches per model, with separate inputs for each keyword.
#  It also handles rendering help for the pattern search bar, via `:show` action
#
################################################################################

module Searchable
  extend ActiveSupport::Concern

  included do
    # Render help for the pattern search bar (if available), for current model
    def show
      respond_to do |format|
        format.turbo_stream do
          render(turbo_stream: turbo_stream.update(
            :search_bar_help, # id of element to update contents of
            partial: "#{search_type}/search/help"
          ))
        end
        format.html
      end
    end

    def new
      set_up_form_field_groupings
      @search = if params[:clear].present?
                  create_query(query_model)
                else
                  find_or_create_query(query_model)
                end

      respond_to do |format|
        format.turbo_stream do
          render(turbo_stream: turbo_stream.update(
            :search_nav_form, # id of element to update contents of
            Components::SearchForm.new(@search, search_controller: self,
                                                local: false)
          ))
        end
        format.html
      end
    end

    def create
      redirect_to(action: :new) and return if clear_form?

      set_up_form_field_groupings # in case we need to re-render the form
      @query_params = params.require(search_object_name).permit(permittables)
      prepare_raw_params
      redirect_to(action: :new) and return unless validate_search_instance?

      save_search_query
      redirect_to(controller: "/#{search_type}", action: :index,
                  q: @query.q_param)
    end

    def prepare_raw_params
      split_names_lookup_strings
      null_box_if_invalid
      null_region_if_overspecific_and_box_valid
      autocompleted_strings_to_ids
      range_fields_to_arrays
      parse_date_ranges
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

    def search_object_name = :"query_#{search_type}"

    def clear_form?
      if params[:commit] == :CLEAR.l
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
      # Nested blank values will make for null query results,
      # so eliminate the whole :names param if it doesn't have a lookup.
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
    def sort_range_values(range)
      return range if range.any?(&:blank?)

      sort_rank_range(range) || sort_numeric_range(range)
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
      [:date, :created_at, :updated_at].each { |field| parse_date_range(field) }
    end

    def parse_date_range(field)
      return if (date = @query_params[field]).blank?

      @query_params[field] = ::DateRangeParser.new(date).range
    end

    # Note that this @search query instance is not the one that gets saved and
    # sent, this step is only for validation of the params and removing blanks.
    # NOTE: We can't call @query_params.compact_blank, because we need to
    # preserve `false` values.
    def validate_search_instance?
      @query_params.reject! { |_k, v| v == "" }
      @search = Query.create_query(query_model, @query_params)
      return true unless @search.invalid?

      messages = @search.validation_errors.compact_blank
      flash_error(messages) if messages
      false
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

    def escape_location_string(location) = "\"#{location.tr(",", "\\,")}\""

    # def strings_with_commas
    #   [:location, :region].freeze
    # end

    def fields_preferring_ids = []

    def fields_with_range = []

    # Passing some fields will raise an error if the required field is missing,
    # so just toss them. Not sure we have to do this, because Query will.
    # def remove_invalid_field_combinations
    #   return unless respond_to?(:fields_with_requirements)

    #   fields_with_requirements.each do |req, fields|
    #     next if @search[req].present?

    #     fields.each { |field| @search.delete(field) }
    #   end
    # end
  end
end
