# frozen_string_literal: true

# Helpers for the Names index. Name-show page logic previously in this helper
# (obs-counting/query links + classification action links) now lives in Tab POROs
# under `Tab::Name::*` and Phlex views under `Views::Controllers::Names::Show::*`.
module NamesHelper
  # Sort options passed to `add_sorter` from the Names index. When
  # the active query is itself ordered by rss_log, "Updated" maps
  # to the rss_log timestamp instead of the name's updated_at.
  # (The pre-relocate version compared against the Symbol
  # `:rss_log`, but `query.params[:order_by]` is stored as a
  # String — the predicate never fired. Fixed here so the
  # documented intent actually takes effect.)
  def names_index_sorts(query: nil)
    rss_log = query&.params&.dig(:order_by) == "rss_log"
    [
      ["name", :sort_by_name.t],
      ["created_at", :sort_by_created_at.t],
      [(rss_log ? "rss_log" : "updated_at"), :sort_by_updated_at.t],
      ["num_views", :sort_by_num_views.t]
    ]
  end
end
