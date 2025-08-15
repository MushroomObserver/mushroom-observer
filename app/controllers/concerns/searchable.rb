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
      # set_up_form_field_groupings
      new_search_instance_from_query
    end

    def create
      return if clear_form?

      # set_up_form_field_groupings # in case we need to re-render the form
      validate_search_instance_from_form_params
      save_search_query

      redirect_to(controller: "/#{parent_controller}", action: :index,
                  q: @query.record.id.alphabetize)
    end

    private

    def clear_form?
      if params[:commit] == :CLEAR.l
        clear_relevant_query
        redirect_to(action: :new) and return true
      end
      false
    end

    # should be new_query_instance. clear_form should update the current query,
    # removing params that wouldn't be in the form (like subqueries)
    def new_search_instance_from_query
      @search = if (@query = find_query(query_model))&.params.present?
                  query_subclass.new(
                    @query.params.permit(permitted_search_params.keys)
                  )
                else
                  query_subclass.new
                end
    end

    def validate_search_instance_from_form_params
      @search = query_subclass.new(
        params.permit(permitted_search_params.keys)
      )
      redirect_to(action: :new) && return if @search.invalid?
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

    # the underscored symbol
    def search_type
      self.class.name.deconstantize.singularize.underscore.to_sym
    end

    # Passing some fields will raise an error if the required field is missing,
    # so just toss them.
    # def remove_invalid_field_combinations
    #   return unless search_subclass.respond_to?(:fields_with_requirements)

    #   search_subclass.fields_with_requirements.each do |req, fields|
    #     next if @keywords[req].present?

    #     fields.each { |field| @keywords.delete(field) }
    #   end
    # end

    def escape_location_string(location)
      "\"#{location.tr(",", "\\,")}\""
    end

    def strings_with_commas
      [:location, :region].freeze
    end
  end
end
