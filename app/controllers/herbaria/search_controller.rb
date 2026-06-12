# frozen_string_literal: true

# Herbaria search form and help.
#
# Route: `herbaria_search_path`, `new_herbaria_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/herbaria/search", action: :create }`
module Herbaria
  class SearchController < ApplicationController
    include ::Searchable

    before_action :login_required

    # Override Searchable#new to render the Phlex view explicitly.
    # (Same pattern as `SpeciesLists::SearchController#new` — see
    # there for the why.)
    def new
      @local = params[:local] != "false"
      set_up_form_field_groupings
      @search = build_search_query
      respond_to do |format|
        format.turbo_stream { render(turbo_stream: turbo_stream_update) }
        format.html do
          render(Views::Controllers::Herbaria::Search::New.new(
                   search: @search, controller: self, local: @local
                 ))
        end
      end
    end

    def permitted_search_params
      [
        :by_users,
        :nonpersonal,
        :code_has,
        :name_has,
        :description_has,
        :mailing_address_has,
        :created_at,
        :updated_at
      ].freeze
    end

    def fields_preferring_ids
      [:by_users]
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
          shown: [:nonpersonal, :by_users, :mailing_address_has]
        }
      },
      {
        detail: {
          shown: [:code_has, :name_has, :description_has]
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
