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

    # Also an index of helper methods to use for each field.
    def permitted_search_params
      {
        by_users: :multiple_value_autocompleter,
        nonpersonal: :select_yes,
        code_has: :text_field_with_label,
        name_has: :text_field_with_label,
        description_has: :text_field_with_label,
        mailing_address_has: :text_field_with_label,
        created_at: :text_field_with_label,
        updated_at: :text_field_with_label
      }.freeze
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
