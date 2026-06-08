# frozen_string_literal: true

# Names index sort table. The runtime sort list is owned by
# `Views::Controllers::Names::Index#sort_options` (which it must
# be, to flip "Updated" → rss_log timestamp when the active
# query is ordered by rss_log). This helper exists ONLY for
# `GeneralExtensions#index_sorts` — the test infrastructure
# probes `@controller.helpers.<controller>_index_sorts` to drive
# `check_index_sorting`.
#
# Keep this list in sync with the view's `sort_options` keys
# (it's the union — every sort key the view can offer).
module NamesHelper
  def names_index_sorts
    [
      ["name",       :sort_by_name.t],
      ["created_at", :sort_by_created_at.t],
      ["updated_at", :sort_by_updated_at.t],
      ["rss_log",    :sort_by_updated_at.t],
      ["num_views",  :sort_by_num_views.t]
    ].freeze
  end
end
