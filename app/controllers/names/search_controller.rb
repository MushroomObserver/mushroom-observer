# frozen_string_literal: true

# Names search form and help.
#
# Route: `names_search_path`, `new_names_search_path`
#
# Call namespaced controller actions with a hash like
# `{ controller: "/names/search", action: :create }`
module Names
  class SearchController < ApplicationController
    include ::Searchable

    before_action :login_required

    # Also an index of helper methods to use for each field.
    def permitted_search_params
      {
        names: :names_fields_for_names,
        pattern: :text_field_with_label,
        has_observations: :select_yes,
        deprecated: :select_boolean,
        has_author: :select_boolean,
        author_has: :text_field_with_label,
        has_citation: :select_boolean,
        citation_has: :text_field_with_label,
        has_classification: :select_boolean,
        classification_has: :text_field_with_label,
        has_notes: :select_boolean,
        notes_has: :text_field_with_label,
        has_comments: :select_yes,
        comments_has: :text_field_with_label,
        has_default_description: :select_boolean,
        created_at: :text_field_with_label,
        updated_at: :text_field_with_label,
        has_synonyms: :select_boolean,
        misspellings: :select_misspellings,
        rank: :select_rank_range,
        lichen: :select_boolean
      }
    end

    def nested_names_params
      {
        include_synonyms: :select_boolean,
        include_subtaxa: :select_boolean,
        include_immediate_subtaxa: :select_boolean,
        exclude_original_names: :select_boolean
      }
    end

    private

    # This is the list of fields that are displayed in the search form. In the
    # template, each hash is interpreted as a column, and each key is a panel
    # with an array of fields or field pairings.
    def set_up_form_field_groupings
      @field_columns = [
        { name: { shown: [:names], collapsed: [[:pattern], [:rank, :lichen]] },
          quality: {
            shown: [[:has_synonyms, :deprecated]],
            collapsed: [[:has_author, :author_has],
                        [:has_citation, :citation_has],
                        [:has_default_description]]
          } },
        { detail: {
            shown: [[:has_classification, :classification_has]],
            collapsed: [[:has_notes, :notes_has],
                        [:has_comments, :comments_has],
                        [:has_observations]]
          },
          date: { shown: [[:created_at, :updated_at]], collapsed: [] } }
      ].freeze
    end
  end
end
