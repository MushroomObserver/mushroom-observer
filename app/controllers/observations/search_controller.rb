# frozen_string_literal: true

# Observations search form and help.
#
# Route: `observations_search_path`, `new_observations_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/observations/search", action: :create }`
module Observations
  class SearchController < ApplicationController
    include ::Searchable

    before_action :login_required

    def permitted_search_params
      [
        :date,
        :created_at,
        :updated_at,
        :names,
        :confidence,
        :has_name,
        :lichen,
        :within_locations,
        :has_public_lat_lng,
        :is_collection_location,
        :region,
        :in_box,
        :has_specimen,
        :has_sequences,
        :has_images,
        :has_notes,
        :has_notes_fields,
        :notes_has,
        :has_comments,
        :comments_has,
        :by_users,
        :projects,
        :herbaria,
        :species_lists,
        :project_lists,
        :field_slips
      ].freeze
    end

    def nested_names_params
      [
        :lookup,
        :include_synonyms,
        :include_subtaxa,
        :include_immediate_subtaxa,
        :exclude_original_names,
        :include_all_name_proposals,
        :exclude_consensus
      ].freeze
    end

    def fields_preferring_ids
      [:by_users, :projects, :herbaria, :project_lists, :species_lists,
       :within_locations]
    end

    def fields_with_range
      [:confidence]
    end

    # def fields_with_requirements
    #   [{ names: [:include_synonyms, :include_subtaxa,
    #              :include_immediate_subtaxa, :exclude_original_names,
    #              :include_all_name_proposals, :exclude_consensus] }]
    # end

    # This is the list of fields that are displayed in the search form. In the
    # template, each hash is interpreted as a column, and each key is a
    # panel_body (either shown or hidden) with an array of fields or field
    # pairings.
    FIELD_COLUMNS = [
      {
        name: {
          shown: [:names],
          # NOTE: These appear via js if names[:lookup] input has any value.
          # See SearchHelper#autocompleter_with_conditional_fields
          # conditional: [[:include_subtaxa, :include_synonyms],
          #               [:include_all_name_proposals, :exclude_consensus]],
          collapsed: [:confidence, [:has_name, :lichen]]
        },
        location: {
          shown: [:within_locations],
          collapsed: [[:has_public_lat_lng, :is_collection_location], :region]
        }
      },
      {
        dates: { shown: [:date], collapsed: [:created_at, :updated_at] },
        detail: {
          shown: [],
          collapsed: [[:has_specimen, :has_sequences],
                      [:has_images, :has_notes],
                      [:has_notes_fields, :notes_has],
                      [:has_comments, :comments_has]]
        },
        connected: {
          shown: [:by_users, :projects],
          collapsed: [:herbaria, :species_lists, :project_lists, :field_slips]
        }
      }
    ].freeze

    private

    # This is the list of fields that are displayed in the search form. In the
    # template, each hash is interpreted as a column, and each key is a
    # panel_body (either shown or hidden) with an array of fields or field
    # pairings.
    def set_up_form_field_groupings
      @field_columns = FIELD_COLUMNS
    end
  end
end
