# frozen_string_literal: true

# Observations search form and help.
#
# Route: `observation_search_path`, `new_observation_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/observations/search", action: :create }`
module Observations
  class SearchController < ApplicationController
    include ::Searchable

    before_action :login_required

    private

    # Also an index of helper methods to use for each field.
    def permitted_search_params
      {
        when: :text_field_with_label,
        created_at: :text_field_with_label,
        updated_at: :text_field_with_label,
        names: :names_fields_for_obs,
        confidence: :select_confidence_range,
        has_name: :select_boolean,
        lichen: :select_boolean,
        location: :multiple_autocompleter,
        has_public_lat_lng: :select_boolean,
        is_collection_location: :select_boolean,
        region: :region_with_compass_fields,
        in_box: :box_fields,
        pattern: :text_field_with_label,
        has_specimen: :select_boolean,
        has_sequences: :select_yes,
        has_images: :select_boolean,
        has_notes: :select_boolean,
        has_field: :text_field_with_label,
        notes_has: :text_field_with_label,
        has_comments: :select_yes,
        comments_has: :text_field_with_label,
        users: :multiple_autocompleter,
        projects: :multiple_autocompleter,
        herbaria: :multiple_autocompleter,
        species_lists: :multiple_autocompleter,
        project_lists: :multiple_autocompleter,
        field_slips: :multiple_autocompleter
      }
    end

    # This is the list of fields that are displayed in the search form. In the
    # template, each hash is interpreted as a column, and each key is a
    # panel_body (either shown or hidden) with an array of fields or field
    # pairings.
    def set_up_form_field_groupings
      @field_columns = [
        { date: { shown: [:when], collapsed: [:created_at, :updated_at] },
          name: {
            shown: [:names],
            # conditional: [[:include_subtaxa, :include_synonyms],
            #               [:include_all_name_proposals, :exclude_consensus]],
            collapsed: [:confidence, [:has_name, :lichen]]
          },
          location: {
            shown: [:location],
            collapsed: [[:has_public_lat_lng, :is_collection_location],
                        [:region], [:in_box]]
          } },
        { pattern: { shown: [:pattern], collapsed: [] },
          detail: {
            shown: [[:has_specimen, :has_sequences]],
            collapsed: [[:has_images, :has_notes],
                        [:has_field, :notes_has],
                        [:has_comments, :comments_has]]
          },
          connected: {
            shown: [:users, :projects],
            collapsed: [:herbaria, :species_lists, :project_lists, :field_slips]
          } }
      ].freeze
    end
  end
end
