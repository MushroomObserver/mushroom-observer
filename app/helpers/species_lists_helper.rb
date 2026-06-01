# frozen_string_literal: true

module SpeciesListsHelper
  # Sort options for the species_lists index page. Used by ERB
  # callers via `add_sorter`. The Phlex equivalent
  # (`Views::Controllers::SpeciesLists::Index`) inlines this array
  # in a private method.
  def species_lists_index_sorts(query: nil)
    rss_log = query&.params&.dig(:order_by) == :rss_log
    [
      ["title",      :sort_by_title.t],
      ["date",       :sort_by_date.t],
      ["user",       :sort_by_user.t],
      ["created_at", :sort_by_created_at.t],
      [(rss_log ? "rss_log" : "updated_at"), :sort_by_updated_at.t]
    ]
  end
end
