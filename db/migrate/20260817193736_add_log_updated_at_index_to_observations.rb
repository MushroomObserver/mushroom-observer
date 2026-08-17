# frozen_string_literal: true

class AddLogUpdatedAtIndexToObservations < ActiveRecord::Migration[7.2]
  # The unfiltered /observations index sorts by :rss_log
  # (log_updated_at DESC, id DESC), the default order -- with no index
  # on log_updated_at, prev/next lookups against that order (see
  # Query::Modules::Seek, #5101) still fall back to a full table scan.
  def change
    add_index(:observations, [:log_updated_at, :id])
  end
end
