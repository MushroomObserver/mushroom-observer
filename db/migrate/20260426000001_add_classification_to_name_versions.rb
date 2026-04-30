# frozen_string_literal: true

# Move classification versioning from name_descriptions onto Name itself.
# `acts_as_versioned` snapshots versioned columns into `name_versions`,
# so the column has to exist on both tables. The corresponding
# `non_versioned_columns` exclusion + `if_changed:` add land in the same
# commit. Discussion #4163.
class AddClassificationToNameVersions < ActiveRecord::Migration[7.2]
  def change
    add_column(:name_versions, :classification, :text)
  end
end
