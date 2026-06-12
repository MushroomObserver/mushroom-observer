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

    # Override Searchable#new to render the Phlex view explicitly.
    # `Searchable` is a shared concern used by 6 search controllers;
    # the other 5 still ship `search/new.erb` and rely on
    # ActionView's implicit template lookup. species_lists is the
    # first to migrate, so this duplicates Searchable#new's
    # 3-line setup rather than threading a `render_search_new_view`
    # hook through the concern just for one caller.
    def new
      @local = params[:local] != "false"
      set_up_form_field_groupings
      @search = build_search_query
      respond_to do |format|
        format.turbo_stream { render(turbo_stream: turbo_stream_update) }
        format.html do
          render(Views::Controllers::SpeciesLists::Search::New.new(
                   search: @search, controller: self, local: @local
                 ))
        end
      end
    end

    def permitted_search_params
      [
        :by_users,
        :projects,
        :names,
        :region,
        :title_has,
        :has_notes,
        :notes_has,
        :has_comments,
        :comments_has,
        :date,
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
