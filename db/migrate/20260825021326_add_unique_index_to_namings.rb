# frozen_string_literal: true

# One user may propose a given Name on a given Observation at most once
# (#5186). Duplicate namings arose from name merges repointing without
# folding, an import that re-created rather than reused, and web-form
# double-submits; the code paths are fixed (#5204) and the existing
# duplicates are collapsed by script/dedup_namings.rb, which must run
# before this migration -- a leftover duplicate makes add_index fail.
#
# Occurrence members keep their own copies: each is a distinct
# Observation, so (observation_id, user_id, name_id) still differs.
# Orphan namings with a NULL observation_id do not collide, since MySQL
# treats NULLs as distinct in a unique index.
class AddUniqueIndexToNamings < ActiveRecord::Migration[7.2]
  def change
    add_index(:namings, [:observation_id, :user_id, :name_id],
              unique: true, name: "index_namings_on_obs_user_name")
  end
end
