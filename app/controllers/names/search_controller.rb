# frozen_string_literal: true

# Names pattern search form.
#
# Route: `new_name_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/names/filter", action: :create }`
module Names
  class SearchController < ApplicationController
    include ::Searchable

    before_action :login_required

    def new
      set_up_form_field_groupings
      new_filter_instance_from_session
    end

    def create
      return if check_for_clear_form

      set_up_form_field_groupings # in case we need to re-render the form
      set_filter_instance_from_form
      set_pattern_string

      redirect_to(controller: "/names", action: :index, pattern: @pattern)
    end

    private

    def check_for_clear_form
      if params[:commit] == :CLEAR.l
        session[:pattern] = ""
        session[:search_type] = nil
        redirect_to(names_new_search_path) and return true
      end
      false
    end

    # should be new_query_instance. clear_form should update the current query.
    def new_filter_instance_from_session
      if (@query = find_query(:Name)).params.present?
        terms = PatternSearch::Name.new(session[:pattern]).form_params
        @filter = NameFilter.new(terms)
      else
        @filter = NameFilter.new
      end
    end

    def set_filter_instance_from_form
      @filter = NameFilter.new(permitted_search_params[:name_filter])
      redirect_to(names_new_search_path) && return if @filter.invalid?
    end

    def set_pattern_string
      @pattern = formatted_pattern_search_string
      # Save it so that we can keep it in the search bar in subsequent pages.
      session[:pattern] = @pattern
      session[:search_type] = :name
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
      params.permit(name_search_params)
    end

    def name_search_params
      [{ name_filter: PatternSearch::Name.fields }]
    end
  end
end
