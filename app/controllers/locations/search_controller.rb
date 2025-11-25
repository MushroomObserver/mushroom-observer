# frozen_string_literal: true

# Locations search form and help.
#
# Route: `locations_search_path`, `new_locations_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/locations/search", action: :create }`
module Locations
  class SearchController < ApplicationController
    include ::Searchable

    before_action :login_required

    def permitted_search_params
      [
        :created_at,
        :updated_at,
        :region,
        :in_box,
        :regexp,
        :has_notes,
        :notes_has,
        :by_users,
        :by_editor,
        :has_descriptions,
        :has_observations
      ].freeze
    end

    def fields_preferring_ids
      [:by_users, :by_editor]
    end

    # def fields_with_requirements
    #   [{ in_box: [:north, :south, :east, :west]
    # end

    # This is the list of fields that are displayed in the search form. In the
    # template, each hash is interpreted as a column, and each key is a
    # panel_body (either shown or hidden) with an array of fields or field
    # pairings.
    FIELD_COLUMNS = [
      {
        area: { shown: [:region] }
      },
      {
        pattern: { shown: [:regexp] },
        dates: { shown: [:created_at, :updated_at] },
        detail: {
          shown: [[:has_notes, :notes_has],
                  [:has_observations, :has_descriptions]]
        },
        connected: { shown: [:by_users, :by_editor] }
      }
    ].freeze

    private

    def set_up_form_field_groupings
      @field_columns = FIELD_COLUMNS
    end
  end
end
