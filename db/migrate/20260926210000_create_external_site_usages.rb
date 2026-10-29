# frozen_string_literal: true

# #5416, #2320: what MO spends against an external site's rate limits.
# iNat publishes two kinds of limit -- requests (100/minute throttled,
# 10,000/day asked) and media downloads (5 GB/hour, 24 GB/day, with a
# permanent block as the stated consequence) -- and MO has been recording
# neither, so its usage could only be reconstructed after the fact from
# import timestamps.
#
# One row per site per ten-minute bucket. Ten minutes rather than an hour
# because both caps are sliding windows: a burst spanning 10:50-11:50
# would split across two hourly rows and the trailing-hour sum would
# undercount it. Six buckets sum to a trailing hour accurate to ten
# minutes, which matches the polling cycle this meters.
#
# Rows are kept indefinitely, deliberately: a year is ~52,500 rows per
# site, a few MB, and the history is what makes year-over-year usage
# reporting possible.
class CreateExternalSiteUsages < ActiveRecord::Migration[7.2]
  def change
    create_table(:external_site_usages, id: :integer,
                                        charset: "utf8mb3") do |t|
      t.integer(:external_site_id, null: false)
      t.datetime(:bucket_start, null: false)
      t.integer(:requests, null: false, default: 0)
      # Split by direction and named for bytes rather than media:
      # iNat only sends MO photos, but a file-based exchange (MO
      # pushes Darwin Core Archives to MyCoPortal, #4216) moves data
      # both ways, and "how much have we sent them" is as worth
      # knowing as how much we pulled.
      t.bigint(:bytes_in, null: false, default: 0)
      t.bigint(:bytes_out, null: false, default: 0)
      # `bucket_start` is the time this row is about, so created_at would
      # duplicate it and updated_at would say when the bucket last took a
      # hit -- neither is worth a column on a row written this often.
      t.timestamps(null: true)

      t.index([:external_site_id, :bucket_start],
              unique: true, name: "index_usages_on_site_and_bucket")
      t.index(:bucket_start)
    end
  end
end
