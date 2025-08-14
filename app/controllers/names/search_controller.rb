# frozen_string_literal: true

# Names pattern search form.
#
# Route: `new_names_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/names/search", action: :create }`
module Names
  class SearchController < ApplicationController
    include ::Searchable

    before_action :login_required

    private

    # Also an index of helper methods to use for each field.
    def permitted_search_params
      {
        names: :names_fields_for_names,
        pattern: :text_field,
        has_observations: :checkbox,
        deprecated: :boolean_select,
        has_author: :boolean_select,
        author_has: :text_field,
        has_citation: :boolean_select,
        citation_has: :text_field,
        has_classification: :boolean_select,
        classifiction_has: :text_field,
        has_notes: :boolean_select,
        notes_has: :text_field,
        has_comments: :checkbox,
        comments_has: :text_field,
        has_default_description: :boolean_select,
        created_at: :text_field,
        updated_at: :text_field,
        has_synonyms: :boolean_select,
        misspellings: :misspelling_select,
        rank: :rank_select,
        lichen: :boolean_select
      }
    end

    # This is the list of fields that are displayed in the search form. In the
    # template, each hash is interpreted as a column, and each key is a panel
    # with an array of fields or field pairings.
    def set_up_form_field_groupings
      @field_columns = [
        { pattern: { shown: [:pattern], collapsed: [] },
          quality: {
            shown: [[:has_observations, :deprecated]],
            collapsed: [[:has_author, :author_has],
                        [:has_citation, :citation_has]]
          },
          date: { shown: [:created_at, :updated_at], collapsed: [] } },
        { scope: {
            shown: [[:has_synonyms, :include_synonyms],
                    [:include_subtaxa, :misspellings]],
            collapsed: [:rank, :lichen]
          },
          detail: {
            shown: [[:has_classification, :classification_has]],
            collapsed: [[:has_notes, :notes_has],
                        [:has_comments, :comments_has],
                        :has_default_description]
          } }
      ].freeze
    end
  end
end
