# frozen_string_literal: true

# Locations search form and help.
#
# Route: `location_search_path`, `new_location_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/locations/search", action: :create }`
module Locations
  class SearchController < ApplicationController
    include ::Searchable

    before_action :login_required

    # Also an index of helper methods to use for each field.
    def permitted_search_params
      {
        created_at: :text_field_with_label,
        updated_at: :text_field_with_label,
        region: :region_with_in_box_fields,
        in_box: :in_box_fields,
        pattern: :text_field_with_label,
        regexp: :text_field_with_label,
        has_notes: :select_boolean,
        notes_has: :text_field_with_label,
        by_users: :multiple_value_autocompleter,
        by_editor: :single_value_autocompleter,
        has_descriptions: :select_boolean,
        has_observations: :select_boolean
      }.freeze
    end

    def fields_preferring_ids
      [:by_users, :by_editor]
    end

    # def fields_with_requirements
    #   [{ in_box: [:north, :south, :east, :west]
    # end

    private

    # This is the list of fields that are displayed in the search form. In the
    # template, each hash is interpreted as a column, and each key is a
    # panel_body (either shown or hidden) with an array of fields or field
    # pairings.
    def set_up_form_field_groupings
      @field_columns = [
        {
          area: { shown: [:region] }
        },
        {
          pattern: { shown: [:pattern], collapsed: [:regexp] },
          dates: { shown: [:created_at, :updated_at] },
          detail: {
            shown: [[:has_notes, :notes_has],
                    [:has_observations, :has_descriptions]]
          },
          connected: { shown: [:by_users, :by_editor] }
        }
      ].freeze
    end
  end
end
