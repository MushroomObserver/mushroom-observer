# frozen_string_literal: true

# SpeciesLists search form and help.
#
# Route: `species_lists_search_path`, `new_species_lists_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/species_lists/search", action: :create }`
module SpeciesLists
  class SearchController < ApplicationController
    include ::Searchable

    before_action :login_required

    # Also an index of helper methods to use for each field.
    def permitted_search_params
      {
        by_users: :multiple_value_autocompleter,
        projects: :multiple_value_autocompleter,
        names: :names_fields_for_obs,
        region: :text_field_with_label,
        title_has: :text_field_with_label,
        has_notes: :select_nil_boolean,
        notes_has: :text_field_with_label,
        has_comments: :select_nil_yes, # ignores false
        comments_has: :text_field_with_label,
        date: :text_field_with_label,
        created_at: :text_field_with_label,
        updated_at: :text_field_with_label
      }.freeze
    end

    def nested_names_params
      {
        include_synonyms: :select_no_eq_nil_or_yes,
        include_subtaxa: :select_no_eq_nil_or_yes,
        include_immediate_subtaxa: :select_no_eq_nil_or_yes,
        exclude_original_names: :select_no_eq_nil_or_yes,
        include_all_name_proposals: :select_no_eq_nil_or_yes,
        exclude_consensus: :select_no_eq_nil_or_yes
      }.freeze
    end

    def fields_preferring_ids
      [:by_users, :projects]
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
          shown: [:names, :region, :projects, :by_users]
        }
      },
      {
        detail: {
          shown: [:title_has, [:has_notes, :notes_has]],
          collapsed: [[:has_comments, :comments_has]]
        },
        dates: { shown: [:date, :created_at, :updated_at] }
      }
    ].freeze

    private

    def set_up_form_field_groupings
      @field_columns = FIELD_COLUMNS
    end
  end
end
