# frozen_string_literal: true

# Names pattern search form.
#
# Route: `new_name_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/names/pattern_search", action: :create }`
module Observations
  class PatternSearchController < ApplicationController
    include ::PatternSearchable

    before_action :login_required

    def new
      @field_columns = observation_field_groups
      terms = PatternSearch::Observation.new(session[:pattern]).form_params

      @filter = if session[:pattern]
                  ObservationFilter.new(terms)
                else
                  ObservationFilter.new
                end
    end

    def create
      @field_columns = observation_field_groups
      @pattern = formatted_pattern_search_string

      # This will save the pattern in the session.
      redirect_to(controller: "/observations", action: :index,
                  pattern: @pattern)
    end

    private

    # This is the list of fields that are displayed in the search form. In the
    # template, each hash is interpreted as a column, and each key is a panel
    # with an array of fields or field pairings.
    def observation_field_groups
      [
        { date: [:when, :created, :modified],
          name: [:name, :confidence, [:has_name, :lichen],
                 [:include_subtaxa, :include_synonyms],
                 [:include_all_name_proposals, :exclude_consensus]],
          location: [:location, :region,
                     [:has_public_lat_lng, :is_collection_location],
                     [:east, :west], [:north, :south]] },
        { detail: [[:has_specimen, :has_sequence], [:has_images, :has_notes],
                   [:has_field, :notes], [:has_comments, :comments]],
          connected: [:user, :herbarium, :list, :project, :project_lists,
                      :field_slip] }
      ].freeze
    end

    def fields_with_dates
      [:when, :created, :modified]
    end

    def fields_with_range
      [:when, :created, :modified, :rank]
    end

    def fields_with_ids
      [:name, :location, :user, :herbarium, :list, :project, :species_list]
    end

    def permitted_search_params
      params.permit(observation_search_params + [
        { when: [:year, :month, :day] },
        { when_range: [:year, :month, :day] },
        { created: [:year, :month, :day] },
        { created_range: [:year, :month, :day] },
        { modified: [:year, :month, :day] },
        { modified_range: [:year, :month, :day] }
      ])
    end

    # need to add :pattern to the list of params, plus the hidden_id fields
    # of the autocompleters.
    def observation_search_params
      PatternSearch::Observation.params.keys + [
        :name_id, :location_id, :user_id, :herbarium_id, :list_id, :project_id,
        :project_lists_id, :rank_range
      ]
    end
  end
end
