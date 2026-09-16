# frozen_string_literal: true

# Third incremental step toward issue #4625 (full utf8mb4 conversion),
# same shape as #5153 and #4804. Query.lookup persists every search as
# a QueryRecord, keyed by a JSON blob in this column (see
# app/classes/query/modules/query_records.rb). A pattern param
# containing an emoji couldn't be written or matched, crashing every
# search that included one (#5188) -- including the iNat import path
# once #4804's fix let an emoji-holding copyright_holder reach the
# database and then get searched.
#
# utf8mb4_general_ci, not utf8mb4_0900_ai_ci, matching #4804/#5153's
# choice: the connection collation is utf8mb4_general_ci, and
# 0900_ai_ci has to wait until #4625 flips the connection collation
# and every table together.
#
# Unlike #4804, this column is not concatenated with another column
# anywhere -- every use is a plain equality,
# QueryRecord.find_by(description:) -- so there's no companion column
# to convert alongside it and no mixed-collation concat risk to
# verify.
class ConvertQueryRecordDescriptionToUtf8mb4 < ActiveRecord::Migration[7.2]
  def up
    change_column(:query_records, :description, :text,
                  collation: "utf8mb4_general_ci")
  end

  def down
    change_column(:query_records, :description, :text,
                  collation: "utf8mb3_general_ci")
  end
end
