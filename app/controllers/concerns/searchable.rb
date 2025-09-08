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
    # We need these arrays to manually prefill nested values from the query.
    #
    # Note that Rails might prefill the values for us if it knew about the
    # objects, i.e. if we we made nested ActiveModels for `:in_box` and the
    # observation/names versions of `:names`. https://jamescrisp.org/2020/10/12/
    # rails-activemodel-with-nested-objects-and-validation/
    # (:names would be a Lookup::Names object, :in_box a Mappable::Box object.)
    # This would require changing some of the attribute defs in Query, though.
    def nested_field_names
      nested_names_param_names + nested_in_box_param_names
    end

    def nested_names_param_names
      keys = nested_names_params&.keys || []
      return keys if keys.blank?

      keys << :lookup
    end

    def nested_in_box_param_names
      [:north, :south, :east, :west].freeze
    end

    # Render help for the pattern search bar (if available), for current model
    def show
      respond_to do |format|
        format.turbo_stream do
          render(turbo_stream: turbo_stream.update(
            :search_nav_help, # id of element to update contents of
            partial: "#{parent_controller}/search/help"
          ))
        end
        format.html
      end
    end

    def new
      set_up_form_field_groupings
      @search = find_or_create_query(query_model)
    end

    def create
      return if clear_form?

      set_up_form_field_groupings # in case we need to re-render the form
      @query_params = params[search_object_name].permit(permittables)
      replace_strings_with_ids
      redirect_to(action: :new) and return unless validate_search_instance?

      save_search_query
      redirect_to(controller: "/#{parent_controller}", action: :index,
                  q: @query.q_param)
    end

    # The form has some additional temporary params, need to permit these
    def permittables
      ranges = fields_with_range.map { |field| :"#{field}_range" }
      ids = fields_preferring_ids.map { |field| :"#{field}_id" }
      permitted_search_params.keys + ranges + ids
    end

    def search_type
      self.class.name.deconstantize.underscore.to_sym
    end

    def search_object_name
      :"query_#{search_type}"
    end

    private

    def clear_form?
      if params[:commit] == :CLEAR.l
        clear_relevant_query
        redirect_to(action: :new) and return true
      end
      false
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

    # Check for `fields_preferring_ids` and swap these in if appropriate
    def replace_strings_with_ids
      return unless respond_to?(:fields_preferring_ids)

      fields_preferring_ids.each do |key|
        next if @query_params[:"#{key}_id"].blank?

        @query_params[key] = @query_params[:"#{key}_id"]
        @query_params.delete(:"#{key}_id")
      end
    end

    # `params.permit` will not accept nested params, or arrays from ranges,
    # so just add them back in. Query will validate and sanitize.
    # Note that this @search query instance is not the one that gets saved and
    # sent, this step is ONLY for validation of the params.
    def validate_search_instance?
      @query_params = {
        **@query_params,
        **nested_params_re_added,
        **joined_range_fields_re_added
      }.deep_symbolize_keys
      @search = Query.create_query(query_model, @query_params)
      return true unless @search.invalid?

      messages = search_query_error_messages
      flash_error(messages) if messages
      false
    end

    def search_query_error_messages
      @search.validation_errors.compact_blank
    end

    # Add the nested params back in if they're present in the original params
    # See note above #validate_search_query_instance_from_params
    def nested_params_re_added
      {
        names: names_with_lookup(params.dig(search_object_name, :names)),
        in_box: in_box_with_values(params.dig(search_object_name, :in_box))
      }.compact_blank
    end

    def names_with_lookup(names)
      return nil if names[:lookup].blank?

      names.permit!
    end

    def in_box_with_values(in_box)
      return nil if in_box.blank? ||
                    (in_box[:north].to_i.zero? && in_box[:south].to_i.zero?)

      in_box.permit!
    end

    # Check for `fields_with_range`, and join them into array if range present
    def joined_range_fields_re_added
      return unless respond_to?(:fields_with_range)

      range_params = {}
      fields_with_range.each do |key|
        next if @query_params[:"#{key}_range"].blank?

        range_params[key] = [@query_params[key], @query_params[:"#{key}_range"]]
      end
      range_params
    end

    def clear_relevant_query
      return if (@query = find_query(query_model))&.params.blank?

      # Save a blank query. This resets the query for this model everywhere.
      @query = Query.lookup_and_save(query_model)
    end

    # Save the validated search params and send these to the index.
    def save_search_query
      @query = Query.lookup_and_save(
        query_model, **@search.params
      )
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
    def query_subclass
      Query.const_get(self.class.module_parent.name)
    end

    def escape_location_string(location)
      "\"#{location.tr(",", "\\,")}\""
    end

    def strings_with_commas
      [:location, :region].freeze
    end

    def fields_preferring_ids
      []
    end

    def fields_with_range
      []
    end
  end
end
