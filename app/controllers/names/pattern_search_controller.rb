# frozen_string_literal: true

# Names pattern search form.
#
# Route: `new_name_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/names/pattern_search", action: :create }`
module Names
  class PatternSearchController < ApplicationController
    include ::PatternSearchable

    before_action :login_required

    def new
      @field_columns = name_field_groups
    end

    def create
      @pattern = formatted_pattern_search_string
      @filter = ObservationFilter.new(
        permitted_search_params[:name_filter]
      )
      redirect_to(controller: "/names", action: :index, pattern: @pattern)
    end

    private

    # This is the list of fields that are displayed in the search form. In the
    # template, each hash is interpreted as a column, and each key is a panel
    # with an array of fields or field pairings.
    def name_field_groups
      [
        { date: [:created, :modified],
          quality: [[:has_observations, :deprecated],
                    [:has_author, :author],
                    [:has_citation, :citation]] },
        { scope: [[:has_synonyms, :include_synonyms],
                  [:include_subtaxa, :include_misspellings],
                  :rank, :lichen],
          detail: [[:has_classification, :classification],
                   [:has_notes, :notes],
                   [:has_comments, :comments],
                   :has_description] }
      ].freeze
    end

    def fields_with_dates
      PatternSearch::Name.fields_with_dates
    end

    def fields_with_range
      PatternSearch::Name.fields_with_range
    end

    def fields_with_ids
      PatternSearch::Name.fields_with_ids
    end

    def permitted_search_params
      params.permit(name_search_params)
    end

    def name_search_params
      [{ name_filter: PatternSearch::Name.fields }]
    end
  end
end
