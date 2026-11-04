# frozen_string_literal: true

# #4625, continuing 20260821200358: every log entry embeds the text of
# whatever it logs, so a comment summary carrying an emoji reached this
# utf8mb3 column and MySQL refused the row -- "Incorrect string value
# '\xF0\x9F\x8D\x84...' for column 'notes'". Converting `comments` and
# the connection was not enough on its own: the comment saved and then
# its RssLog entry failed, which is a 500 either way.
#
# No index on `notes` and no search scope concatenating it, so neither
# the index-key-length limit that defers #4625 nor the CONCAT collation
# aggregation that shaped 20260821200358 applies here.
#
# utf8mb4_general_ci to match the connection collation and the columns
# converted so far, not the newer utf8mb4_0900_ai_ci -- see
# 20260821200358 for why that waits for #4625 to move every table at
# once.
class ConvertRssLogNotesToUtf8mb4 < ActiveRecord::Migration[7.2]
  def up
    change_column(:rss_logs, :notes, :text,
                  collation: "utf8mb4_general_ci")
  end

  def down
    change_column(:rss_logs, :notes, :text,
                  collation: "utf8mb3_general_ci")
  end
end
