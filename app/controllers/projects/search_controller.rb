# frozen_string_literal: true

# Projects search form and help.
#
# Route: `project_search_path`, `new_project_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/projects/search", action: :create }`
module Projects
  class SearchController < ApplicationController
    include ::Searchable

    before_action :login_required

    # Also an index of helper methods to use for each field.
    def permitted_search_params
      {
        members: :multiple_value_autocompleter,
        names: :names_fields_for_obs,
        region: :text_field_with_label,
        field_slip_prefix_has: :text_field_with_label,
        by_users: :multiple_value_autocompleter,
        has_observations: :select_yes, # ignores false
        has_images: :select_yes,
        has_species_lists: :select_yes,
        title_has: :text_field_with_label,
        has_summary: :select_boolean,
        summary_has: :text_field_with_label,
        has_notes: :select_boolean,
        notes_has: :text_field_with_label,
        has_comments: :select_yes,
        comments_has: :text_field_with_label,
        created_at: :text_field_with_label,
        updated_at: :text_field_with_label
      }.freeze
    end

    def nested_names_params
      {
        include_synonyms: :select_boolean,
        include_subtaxa: :select_boolean,
        include_immediate_subtaxa: :select_boolean,
        exclude_original_names: :select_boolean,
        include_all_name_proposals: :select_boolean,
        exclude_consensus: :select_boolean
      }.freeze
    end

    def fields_preferring_ids
      [:by_users, :members]
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
        connected: {
          shown: [:members, :names, :region],
          collapsed: [:field_slip_prefix_has, :by_users,
                      [:has_observations, :has_species_lists],
                      [:has_images]]
        }
      },
      {
        detail: {
          shown: [:title_has, [:has_summary, :summary_has]],
          collapsed: [[:has_comments, :comments_has]]
        },
        dates: { shown: [:created_at, :updated_at] }
      }
    ].freeze

    private

    def set_up_form_field_groupings
      @field_columns = FIELD_COLUMNS
    end
  end
end
