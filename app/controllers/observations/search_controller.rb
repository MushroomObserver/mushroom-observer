# frozen_string_literal: true

# Observations pattern search form.
#
# Route: `new_observation_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/observations/search", action: :create }`
module Observations
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

      redirect_to(controller: "/observations", action: :index,
                  pattern: @pattern)
    end

    private

    def check_for_clear_form
      if params[:commit] == :CLEAR.l
        session[:pattern] = ""
        session[:search_type] = nil
        redirect_to(observations_new_search_path) and return true
      end
      false
    end

    def new_filter_instance_from_session
      if session[:pattern].present? && session[:search_type] == :observation
        terms = PatternSearch::Observation.new(session[:pattern]).form_params
        @filter = ObservationFilter.new(terms)
      else
        @filter = ObservationFilter.new
      end
    end

    def set_filter_instance_from_form
      @filter = ObservationFilter.new(
        permitted_search_params[:observation_filter]
      )
      redirect_to(observations_new_search_path) && return if @filter.invalid?
    end

    def set_pattern_string
      @pattern = formatted_pattern_search_string
      # Save it so that we can keep it in the search bar in subsequent pages.
      session[:pattern] = @pattern
      session[:search_type] = :observation
    end

    # This is the list of fields that are displayed in the search form. In the
    # template, each hash is interpreted as a column, and each key is a
    # panel_body (either shown or hidden) with an array of fields or field
    # pairings.
    def set_up_form_field_groupings
      @field_columns = [
        { date: { shown: [:when], collapsed: [:created, :modified] },
          name: {
            shown: [:name],
            conditional: [[:include_subtaxa, :include_synonyms],
                          [:include_all_name_proposals, :exclude_consensus]],
            collapsed: [:confidence, [:has_name, :lichen]]
          },
          location: {
            shown: [:location],
            collapsed: [[:has_public_lat_lng, :is_collection_location],
                        :region, [:east, :west], [:north, :south]]
          } },
        { pattern: { shown: [:pattern], collapsed: [] },
          detail: {
            shown: [[:has_specimen, :has_sequence]],
            collapsed: [[:has_images, :has_notes],
                        [:has_field, :notes], [:has_comments, :comments]]
          },
          connected: {
            shown: [:user, :project],
            collapsed: [:herbarium, :list, :project_lists, :field_slip]
          } }
      ].freeze
    end

    def permitted_search_params
      params.permit(observation_search_params)
    end

    # need to add :pattern to the list of params, plus the hidden_id fields
    # of the autocompleters.
    def observation_search_params
      [{ observation_filter: PatternSearch::Observation.fields }]
    end
  end
end
