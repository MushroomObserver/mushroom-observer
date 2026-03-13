# frozen_string_literal: true

# Projects search form and help.
#
# Route: `projects_search_path`, `new_projects_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/projects/search", action: :create }`
module Projects
  class SearchController < ApplicationController
    include ::Searchable

    before_action :login_required

    def permitted_search_params
      [
        :members,
        :names,
        :region,
        :field_slip_prefix_has,
        :by_users,
        :has_observations,
        :has_images,
        :has_species_lists,
        :title_has,
        :has_summary,
        :summary_has,
        :has_notes,
        :notes_has,
        :has_comments,
        :comments_has,
        :created_at,
        :updated_at
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
