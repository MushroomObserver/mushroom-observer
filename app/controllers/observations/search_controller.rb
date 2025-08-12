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
      new_search_instance_from_query
    end

    def create
      return if clear_form?

      set_up_form_field_groupings # in case we need to re-render the form
      validate_search_instance_from_form_params
      save_query

      redirect_to(controller: "/observations", action: :index,
                  q: @query.record.id.alphabetize)
    end

    private

    def clear_form?
      if params[:commit] == :CLEAR.l
        clear_relevant_query
        redirect_to(new_observations_search_path) and return true
      end
      false
    end

    def new_search_instance_from_query
      @search = if (@query = find_query(:Observation)).params.present?
                  Search::Observations.new(@query.params)
                else
                  Search::Observations.new
                end
    end

    def validate_search_instance_from_form_params
      @search = Search::Observations.new(permitted_search_params)
      redirect_to(new_observations_search_path) && return if @search.invalid?
    end

    def clear_relevant_query
      return if (@query = find_query(:Observation)).params.blank?

      # Save blank so that we can keep it in the search bar in subsequent pages.
      @query = Query.lookup_and_save(:Observation)
    end

    def save_query
      Query.lookup_and_save(:Observation, **@search)
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
      params.permit(Search::Observations.attribute_names)
    end
  end
end
