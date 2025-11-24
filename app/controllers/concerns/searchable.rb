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
            partial: "#{parent_controller}/search/help"
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
            partial: "shared/search_form",
            locals: { local: false, search: @search,
                      field_columns: @field_columns }
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
      redirect_to(controller: "/#{parent_controller}", action: :index,
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
      nested_names_param_names + nested_in_box_param_names
    end

    # Default. Override in controllers
    def nested_names_params
      {}
    end

    # Used by search_form
    def search_type
      self.class.name.deconstantize.underscore.to_sym
    end

    def parent_controller
      self.class.name.deconstantize.underscore
    end

    # Returns the capitalized :Symbol used by Query for the type of query.
    def query_model
      self.class.module_parent.name.singularize.to_sym
    end

    private

    def search_object_name
      :"query_#{search_type}"
    end

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
      names = { names: nested_names_param_names }
      in_box = { in_box: nested_in_box_param_names }
      perm = permitted_search_params.keys + ranges + ids
      perm << names
      perm << in_box
      perm
    end

    def nested_names_param_names
      keys = nested_names_params&.keys || []
      return keys if keys.blank?

      keys << :lookup
    end

    def nested_in_box_param_names
      [:north, :south, :east, :west].freeze
    end

    def split_names_lookup_strings
      # Nested blank values will make for null query results,
      # so eliminate the whole :names param if it doesn't have a lookup.
      if (vals = @query_params.dig(:names, :lookup)).blank?
        @query_params[:names] = nil
        return
      end

      @query_params[:names][:lookup] = vals.split("\r\n")
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

    # Check for `fields_with_range`, and join them into array if range present
    def range_fields_to_arrays
      return unless respond_to?(:fields_with_range)

      fields_with_range.each do |key|
        next if @query_params[:"#{key}_range"].blank?

        @query_params[key] = [@query_params[key],
                              @query_params[:"#{key}_range"]]
        @query_params.delete(:"#{key}_range")
      end
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

    def escape_location_string(location)
      "\"#{location.tr(",", "\\,")}\""
    end

    # def strings_with_commas
    #   [:location, :region].freeze
    # end

    def fields_preferring_ids
      []
    end

    def fields_with_range
      []
    end

    # Passing some fields will raise an error if the required field is missing,
    # so just toss them. Not sure we have to do this, because Query will.
    # def remove_invalid_field_combinations
    #   return unless respond_to?(:fields_with_requirements)

    #   fields_with_requirements.each do |req, fields|
    #     next if @search[req].present?

    #     fields.each { |field| @search.delete(field) }
    #   end
    # end

    # The controllers define how they're going to parse their
    # fields, so we can use that to assign a field helper.
    def search_field_type_from_controller(field:)
      # return :pattern if field == :pattern

      defined = permitted_search_params.merge(nested_names_params)
      unless defined[field]
        raise("No input defined for #{field} in #{controller_name}")
      end

      search_field_ui(field)
    end
    helper_method :search_field_type_from_controller

    def search_field_ui(field) # rubocop:disable Metrics/CyclomaticComplexity
      # handle exceptions first
      case field
      when :names
        names_field_ui_for_this_controller
      when :lookup
        :multiple_value_autocompleter
      when :include_synonyms, :include_subtaxa,
        :include_immediate_subtaxa, :exclude_original_names,
        :exclude_consensus, :include_all_name_proposals
        :select_no_eq_nil_or_yes
      when :misspellings
        :select_misspellings
      when :rank
        :select_rank_range
      when :confidence
        :select_confidence_range
      when :region
        region_field_ui_for_this_controller
      when :in_box
        :in_box_fields
      when :field_slips
        :text_field_with_label
      else
        field_ui_by_query_attr_definition(field)
      end
    end

    def field_ui_by_query_attr_definition(field)
      definition = query_subclass.attribute_types[field]&.accepts
      case definition
      when :boolean
        :select_nil_boolean
      when :string
        :text_field_with_label
      when Array
        field_ui_for_array_definition(definition)
      when Class
        :single_value_autocompleter
      when Hash
        field_ui_for_hash_definition(definition)
      end
    end

    # e.g. { boolean: [true] }
    def field_ui_for_hash_definition(definition)
      case definition.keys.first.to_sym
      when :boolean
        :select_nil_yes
      end
    end

    # e.g. [:string], [Location]
    def field_ui_for_array_definition(definition)
      case definition.first
      when :string, :time, :date
        :text_field_with_label
      when Class
        :multiple_value_autocompleter
      end
    end

    # Gets the query class relevant to each controller, assuming the controller
    # is namespaced like Observations::SearchController
    def query_subclass
      Query.const_get(self.class.module_parent.name)
    end

    def names_field_ui_for_this_controller
      case search_type
      when :observations, :projects, :species_lists
        :names_fields_for_obs
      when :names
        :names_fields_for_names
      end
    end

    def region_field_ui_for_this_controller
      case search_type
      when :observations, :locations
        :region_with_in_box_fields
      else
        :text_field_with_label
      end
    end
  end
end
