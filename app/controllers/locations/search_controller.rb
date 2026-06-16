# frozen_string_literal: true

# Locations search form and help.
#
# Route: `locations_search_path`, `new_locations_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/locations/search", action: :create }`
module Locations
  class SearchController < ApplicationController
    include ::Searchable

    before_action :login_required

    def permitted_search_params
      [
        :created_at,
        :updated_at,
        :region,
        :in_box,
        :regexp,
        :has_notes,
        :notes_has,
        :by_users,
        :by_editor,
        :has_descriptions,
        :has_observations
      ].freeze
    end

    def fields_preferring_ids
      [:by_users, :by_editor]
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
        pattern: { shown: [:regexp] },
        area: { shown: [:region] }
      },
      {
        dates: { shown: [:created_at, :updated_at] },
        detail: {
          shown: [[:has_notes, :notes_has],
                  [:has_observations, :has_descriptions]]
        },
        connected: { shown: [:by_users, :by_editor] }
      }
    ].freeze

    def show
      respond_to do |format|
        format.turbo_stream do
          render(turbo_stream: turbo_stream.update(
            :search_bar_help,
            Views::Controllers::Locations::Search::Help.new
          ))
        end
        format.html do
          render(Views::Controllers::Locations::Search::Show.new)
        end
      end
    end

    # Override the Searchable concern's HTML branches so the form +
    # help page render the Phlex views instead of the deleted ERBs.
    def new
      @local = params[:local] != "false"
      set_up_form_field_groupings
      @search = build_search_query
      respond_to do |format|
        format.turbo_stream { render(turbo_stream: turbo_stream_update) }
        format.html do
          render(Views::Controllers::Locations::Search::New.new(
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
