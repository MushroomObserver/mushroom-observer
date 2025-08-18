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
        locations: :multiple_value_autocompleter,
        has_public_lat_lng: :select_boolean,
        is_collection_location: :select_boolean,
        region: :region_with_in_box_fields,
        in_box: :in_box_fields,
        pattern: :text_field_with_label,
        has_specimen: :select_boolean,
        has_sequences: :select_yes,
        has_images: :select_boolean,
        has_notes: :select_boolean,
        has_field: :text_field_with_label,
        notes_has: :text_field_with_label,
        has_comments: :select_yes,
        comments_has: :text_field_with_label,
        by_users: :multiple_value_autocompleter,
        projects: :multiple_value_autocompleter,
        herbaria: :multiple_value_autocompleter,
        species_lists: :multiple_value_autocompleter,
        project_lists: :multiple_value_autocompleter,
        field_slips: :text_field_with_label
      }
    end

    def nested_names_params
      {
        include_synonyms: :select_boolean,
        include_subtaxa: :select_boolean,
        include_immediate_subtaxa: :select_boolean,
        exclude_original_names: :select_boolean,
        include_all_name_proposals: :select_boolean,
        exclude_consensus: :select_boolean
      }
    end

    private

    # This is the list of fields that are displayed in the search form. In the
    # template, each hash is interpreted as a column, and each key is a
    # panel_body (either shown or hidden) with an array of fields or field
    # pairings.
    def set_up_form_field_groupings
      @field_columns = [
        {
          date: { shown: [:when], collapsed: [:created_at, :updated_at] },
          name: {
            shown: [:names],
            # conditional: [[:include_subtaxa, :include_synonyms],
            #               [:include_all_name_proposals, :exclude_consensus]],
            collapsed: [:confidence, [:has_name, :lichen]]
          },
          location: {
            shown: [:locations],
            collapsed: [[:has_public_lat_lng, :is_collection_location],
                        :region]
          }
        },
        {
          pattern: { shown: [:pattern], collapsed: [] },
          detail: {
            shown: [[:has_specimen, :has_sequences]],
            collapsed: [[:has_images, :has_notes],
                        [:has_field, :notes_has],
                        [:has_comments, :comments_has]]
          },
          connected: {
            shown: [:by_users, :projects],
            collapsed: [:herbaria, :species_lists, :project_lists, :field_slips]
          }
        }
      ].freeze
    end
  end
end
