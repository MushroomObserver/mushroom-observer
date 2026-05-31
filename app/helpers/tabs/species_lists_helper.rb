# frozen_string_literal: true

module Tabs
  module SpeciesListsHelper
    # The bulk of the species_list tab definitions migrated to PORO
    # classes under `app/classes/tab/species_list/*.rb` (17 single
    # Tab POROs + 6 Tab::Collection subclasses — Show, FormNew,
    # FormWriteIn, FormObservations, FormNameList, etc.). The two
    # collection methods below call `object_return_tab` from
    # `Tabs::GeneralHelper` — they stay as helpers until PR 4 of the
    # migration converts general_helper. Each one composes the new
    # Tab POROs internally where possible.

    def species_list_form_edit_tabs(list:)
      [
        object_return_tab(list),
        ::Tab::SpeciesList::Upload.new(list: list).to_a
      ]
    end

    def species_list_edit_project_tabs(list:)
      [object_return_tab(list)]
    end

    # Sort options for the species_lists index page. Non-tab helper
    # — relocates to a new `app/helpers/species_lists_helper.rb` (or
    # similar) in PR 4 when this file gets fully deleted.
    def species_lists_index_sorts(query: nil)
      [
        ["title",       :sort_by_title.t],
        ["date",        :sort_by_date.t],
        ["user",        :sort_by_user.t],
        ["created_at",  :sort_by_created_at.t],
        [(query&.params&.dig(:order_by) == :rss_log ? "rss_log" : "updated_at"),
         :sort_by_updated_at.t]
      ]
    end
  end
end
