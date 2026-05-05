# frozen_string_literal: true

# Three indexes that close gaps surfaced by the slow query log during
# the 2026-04-27 outage. All three drive frequently-hit queries that
# were doing full table scans of tables with 1.8M+ rows.
#
# - `observation_images.image_id` (#4175): touch propagation from an
#   Image to its associated Observations runs an UPDATE-with-JOIN
#   keyed on `image_id`. Currently scans the full table per call;
#   creating an observation with N images costs ~2.5N seconds of pure
#   scan time. With the index each lookup is sub-millisecond.
# - `rss_logs.updated_at` (#4176): the activity-feed sort key. With
#   no index, every page load that hits the feed scans 1.98M rows to
#   sort. With the index `ORDER BY updated_at DESC LIMIT N` walks the
#   index backward.
# - `rss_logs.observation_id` (#4176): the join key into observations
#   used by the same activity-feed dedup logic. Without it the LEFT
#   JOIN does a full row scan per matched rss_log.
class AddIndexesForSlowQueries < ActiveRecord::Migration[7.2]
  def change
    add_index(:observation_images, :image_id,
              name: "index_observation_images_on_image_id")
    add_index(:rss_logs, :updated_at,
              name: "index_rss_logs_on_updated_at")
    add_index(:rss_logs, :observation_id,
              name: "index_rss_logs_on_observation_id")
  end
end
