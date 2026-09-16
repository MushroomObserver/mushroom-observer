# frozen_string_literal: true

class AddLogUpdatedAtIndexToObservations < ActiveRecord::Migration[7.2]
  # The unfiltered /observations index sorts by :rss_log
  # (log_updated_at DESC, id DESC), the default order. Prep for #5101's
  # bounded prev/next lookup, which queries this order with a WHERE +
  # LIMIT 1 -- an index range scan instead of a full table scan.
  def change
    add_index(:observations, [:log_updated_at, :id])
  end
end
