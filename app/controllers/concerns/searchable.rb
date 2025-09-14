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
      @search = find_or_create_query(query_model)

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
      return if clear_form?

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
      null_in_box_if_empty
      autocompleted_strings_to_ids
      range_fields_to_arrays
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

    private

    def search_object_name
      :"query_#{search_type}"
    end

    def clear_form?
      if params[:commit] == :CLEAR.l
        clear_relevant_query
        redirect_to(action: :new) and return true
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
    def null_in_box_if_empty
      south = @query_params.dig(:in_box, :south)
      north = @query_params.dig(:in_box, :north)
      return unless (south.blank? || south.to_f.zero?) &&
                    (north.blank? || north.to_f.zero?)

      @query_params[:in_box] = nil
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

    # Note that this @search query instance is not the one that gets saved and
    # sent, this step is only for validation of the params.
    def validate_search_instance?
      @search = Query.create_query(query_model, @query_params)
      return true unless @search.invalid?

      messages = @search.validation_errors.compact_blank
      flash_error(messages) if messages
      false
    end

    def clear_relevant_query
      return if (@query = find_query(query_model))&.params.blank?

      # Save a blank query. This resets the query for this model everywhere.
      @query = Query.lookup_and_save(query_model)
    end

    # Save the validated search params and send these to the index.
    def save_search_query
      @query = Query.lookup_and_save(query_model, **@search.params)
    end

    def parent_controller
      self.class.name.deconstantize.underscore
    end

    # Returns the capitalized :Symbol used by Query for the type of query.
    def query_model
      self.class.module_parent.name.singularize.to_sym
    end

    # Gets the query class relevant to each controller, assuming the controller
    # is namespaced like Observations::SearchController
    # def query_subclass
    #   Query.const_get(self.class.module_parent.name)
    # end

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
  end
end
