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

    def permitted_search_params
      [
        :names,
        :has_observations,
        :deprecated,
        :has_author,
        :author_has,
        :has_citation,
        :citation_has,
        :has_classification,
        :classification_has,
        :has_notes,
        :notes_has,
        :has_comments,
        :comments_has,
        :has_default_description,
        :created_at,
        :updated_at,
        :has_synonyms,
        :misspellings,
        :rank,
        :lichen
      ].freeze
    end

    def nested_names_params
      [
        :lookup,
        :include_synonyms,
        :include_subtaxa,
        :include_immediate_subtaxa,
        :exclude_original_names
      ].freeze
    end

    def fields_with_range
      [:rank]
    end

    # This is the list of fields that are displayed in the search form. In the
    # template, each hash is interpreted as a column, and each key is a panel
    # with an array of fields or field pairings.
    FIELD_COLUMNS = [
      { name: {
        shown: [:names],
        # NOTE: These appear via js if names[:lookup] input has any value.
        # See SearchHelper#autocompleter_with_conditional_fields
        # conditional: [
        #   [:include_subtaxa, :include_synonyms],
        #   [:include_immediate_subtaxa, :exclude_original_names]
        # ],
        collapsed: [[:deprecated, :lichen],
                    :rank,
                    [:has_author, :author_has],
                    [:has_citation, :citation_has],
                    [:has_default_description, :misspellings]]
      } },
      { detail: {
          shown: [[:has_classification, :classification_has]],
          collapsed: [[:has_notes, :notes_has],
                      [:has_comments, :comments_has],
                      [:has_observations]]
        },
        dates: { shown: [[:created_at, :updated_at]], collapsed: [] } }
    ].freeze

    # Overrides `Searchable#show` — the turbo_stream branch points
    # at a now-Phlex help view, and the html branch needs an
    # explicit Phlex render since the `show.erb` template is gone.
    def show
      respond_to do |format|
        format.turbo_stream do
          render(turbo_stream: turbo_stream.update(
            :search_bar_help,
            Views::Controllers::Names::Search::Help.new
          ))
        end
        format.html do
          render(Views::Controllers::Names::Search::Show.new)
        end
      end
    end

    # Overrides `Searchable#new` so the html branch renders the
    # Phlex view explicitly.
    def new
      @local = params[:local] != "false"
      set_up_form_field_groupings
      @search = build_search_query
      respond_to do |format|
        format.turbo_stream { render(turbo_stream: turbo_stream_update) }
        format.html do
          render(Views::Controllers::Names::Search::New.new(
                   search: @search, local: @local
                 ))
        end
      end
    end

    private

    def set_up_form_field_groupings
      @field_columns = FIELD_COLUMNS
    end
  end
end
