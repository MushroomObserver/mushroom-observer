# frozen_string_literal: true

# Drop the `name_descriptions.classification` column and its
# corresponding column on the version history table. Classification
# now lives only on Name and is versioned via `name_versions`
# (discussion #4163). All read paths and the `update_classification_cache`
# callback were removed in the prior commit.
class RemoveClassificationFromNameDescriptions < ActiveRecord::Migration[7.2]
  def change
    remove_column(:name_descriptions, :classification, :text)
    remove_column(:name_description_versions, :classification, :text)
  end
end
