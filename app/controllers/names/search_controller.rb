# frozen_string_literal: true

# Names pattern search form.
#
# Route: `new_names_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/names/search", action: :create }`
module Names
  class SearchController < ApplicationController
    include ::Searchable

    before_action :login_required

    def new
      set_up_form_field_groupings
      new_search_instance_from_query
    end

    def create
      return if clear_form?

      set_up_form_field_groupings # in case we need to re-render the form
      validate_search_instance_from_form_params
      clear_relevant_query

      redirect_to(controller: "/names", action: :index, pattern: @pattern)
    end

    private

    def clear_form?
      if params[:commit] == :CLEAR.l
        clear_relevant_query
        redirect_to(new_names_search_path) and return true
      end
      false
    end

    # should be new_query_instance. clear_form should update the current query.
    def new_search_instance_from_query
      @search = if (@query = find_query(:Name)).params.present?
                  Search::Names.new(@query.params)
                else
                  Search::Names.new
                end
    end

    def validate_search_instance_from_form_params
      @search = Search::Names.new(permitted_search_params)
      redirect_to(new_names_search_path) && return if @search.invalid?
    end

    def clear_relevant_query
      return if (@query = find_query(:Name)).params.blank?

      # Save blank so that we can keep it in the search bar in subsequent pages.
      @query = Query.lookup_and_save(:Name)
    end

    # This is the list of fields that are displayed in the search form. In the
    # template, each hash is interpreted as a column, and each key is a panel
    # with an array of fields or field pairings.
    def set_up_form_field_groupings
      @field_columns = [
        { pattern: { shown: [:pattern], collapsed: [] },
          quality: {
            shown: [[:has_observations, :deprecated]],
            collapsed: [[:has_author, :author],
                        [:has_citation, :citation]]
          },
          date: { shown: [:created, :modified], collapsed: [] } },
        { scope: {
            shown: [[:has_synonyms, :include_synonyms],
                    [:include_subtaxa, :include_misspellings]],
            collapsed: [:rank, :lichen]
          },
          detail: {
            shown: [[:has_classification, :classification]],
            collapsed: [[:has_notes, :notes],
                        [:has_comments, :comments],
                        :has_description]
          } }
      ].freeze
    end

    def permitted_search_params
      params.permit(Search::Names.attribute_names)
    end
  end
end
