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

    def new
      # set_up_form_field_groupings
      new_search_instance_from_query
    end

    def create
      return if clear_form?

      # set_up_form_field_groupings # in case we need to re-render the form
      validate_search_instance_from_form_params
      save_search_query

      redirect_to(controller: "/names", action: :index,
                  q: @query.record.id.alphabetize)
    end

    private

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
