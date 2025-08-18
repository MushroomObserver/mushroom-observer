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
      new_search_instance_from_query
    end

    def create
      return if clear_form?

      set_up_form_field_groupings # in case we need to re-render the form
      replace_strings_with_ids
      concatenate_range_fields
      validate_search_query_instance_from_params
      save_search_query

      redirect_to(controller: "/#{parent_controller}", action: :index,
                  q: @query.record.id.alphabetize)
    end

    def search_type
      self.class.name.deconstantize.underscore.to_sym
    end

    private

    def clear_form?
      if params[:commit] == :CLEAR.l
        clear_relevant_query
        redirect_to(action: :new) and return true
      end
      false
    end

    # Should be new_query_instance. clear_form should update the current query,
    # removing params that wouldn't be in the form (like subqueries).
    # Need to parse and prepopulate range fields if there is a query.
    def new_search_instance_from_query
      @search = if (@query = find_query(query_model))&.params.present?
                  query_subclass.new(
                    @query.params.permit(permitted_search_params.keys)
                  )
                else
                  query_subclass.new
                end
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
        next if params[:"#{key}_id"].blank?

        params[key] = params[:"#{key}_id"]
      end
    end

    # Check for `fields_with_range`, and concatenate them if range val present
    def concatenate_range_fields # rubocop:disable Metrics/AbcSize
      return unless respond_to?(:fields_with_range)

      fields_with_range.each do |key|
        next if params[:"#{key}_range"].blank?

        params[key] = [params[key].to_s.strip,
                       params[:"#{key}_range"].to_s.strip].join("-")
      end
    end

    # `params.permit` will not accept nested params, so just add them back in.
    # Query will validate and sanitize.
    def validate_search_query_instance_from_params
      @search = query_subclass.new(
        **params.permit(permitted_search_params.keys),
        **nested_params_re_added
      )
      redirect_to(action: :new) and return if @search.invalid?
    end

    # Add the nested params back in if they're present
    def nested_params_re_added
      { names: names_with_lookup,
        in_box: in_box_with_values }.compact_blank
    end

    def names_with_lookup
      return nil if params.dig(:names, :lookup).blank?

      params[:names].to_unsafe_hash
    end

    def in_box_with_values
      return nil if params[:in_box].blank? ||
                    (params.dig(:in_box, :north).to_i.zero? &&
                     params.dig(:in_box, :south).to_i.zero?)

      params[:in_box].to_unsafe_hash
    end

    def clear_relevant_query
      return if (@query = find_query(query_model))&.params.blank?

      # Save a blank query. This resets the query for this model everywhere.
      @query = Query.lookup_and_save(query_model)
    end

    def save_search_query
      @query = Query.lookup_and_save(
        query_model, **@search.attributes.deep_symbolize_keys.compact_blank
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
  end
end
