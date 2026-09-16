# frozen_string_literal: true

class AddDateSortIndexesToObservations < ActiveRecord::Migration[7.2]
  # The observations index's Date and Date Posted sorts order by
  # (`when` DESC, id DESC) and (created_at DESC, id DESC). Without
  # these indexes, the prev/next pager's bounded window fill for those
  # orders runs at full-scan speed (~450ms measured) -- the same
  # one-line fix the log_updated_at index was for the :rss_log order.
  def change
    add_index(:observations, [:when, :id])
    add_index(:observations, [:created_at, :id])
  end
end
