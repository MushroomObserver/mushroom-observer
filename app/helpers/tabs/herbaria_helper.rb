# frozen_string_literal: true

module Tabs
  module HerbariaHelper
    # The tab definitions migrated to PORO classes under
    # `app/classes/tab/herbarium/*.rb` — 5 single Tab POROs (`New`,
    # `ListAll`, `Return`, `NonpersonalIndex`,
    # `LabeledNonpersonalIndex`) + 5 `Tab::Collection` subclasses
    # (`Index`, `Show`, `FormNew`, `FormEdit`, `CuratorRequest`).
    # `Tabs::HerbariumRecordsHelper` still `include`s this module for
    # the `*_index_sorts` definitions below; the include can drop
    # when the sorts also relocate (PR 4 of the migration plan).

    def herbaria_index_sorts(query: nil)
      if query&.params&.dig(:nonpersonal)
        return nonpersonal_herbaria_index_sorts
      end

      full_herbaria_index_sorts
    end

    def full_herbaria_index_sorts
      [
        ["records",     :sort_by_records.t],
        ["curator",     :sort_by_curator.t],
        ["code",        :sort_by_code.t],
        ["name",        :sort_by_name.t],
        ["created_at",  :sort_by_created_at.t],
        ["updated_at",  :sort_by_updated_at.t]
      ].freeze
    end

    def nonpersonal_herbaria_index_sorts
      # must dup a frozen array, this is new ruby 3 policy
      sorts = full_herbaria_index_sorts.map(&:clone)
      sorts.reject! { |x| x[0] == "user" }
    end
  end
end
