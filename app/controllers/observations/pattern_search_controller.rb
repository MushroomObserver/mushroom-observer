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
      @fields = observation_search_params
    end

    def create
      @pattern = human_formatted_pattern_search_string
      redirect_to(controller: "/observations", action: :index,
                  pattern: @pattern)
    end

    private

    def permitted_search_params
      params.permit(observation_search_params)
    end

    # need to add :pattern to the list of params, plus the hidden_id fields
    # of the autocompleters.
    def observation_search_params
      PatternSearch::Observation.params.keys + [
        :pattern, :name_id, :user_id, :location_id, :species_list_id,
        :project_id, :herbarium_id
      ]
    end
  end
end
