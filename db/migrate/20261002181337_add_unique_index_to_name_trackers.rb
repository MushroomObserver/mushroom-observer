# frozen_string_literal: true

# One tracker per user and Name (#5458). Existing duplicates need the
# repair below first; it keeps one tracker per pair and destroys the
# others with their Interests.
class AddUniqueIndexToNameTrackers < ActiveRecord::Migration[7.2]
  REPAIR = "bin/rails runner script/remove_duplicate_name_trackers.rb --apply"

  # A copy of the table as this migration needs it, rather than the
  # application's model -- that one goes on changing after this
  # migration is written.
  class MigrationNameTracker < ActiveRecord::Base
    self.table_name = "name_trackers"
  end

  def up
    refuse_until_repaired
    add_index(:name_trackers, [:user_id, :name_id], unique: true)
  end

  def down
    remove_index(:name_trackers, [:user_id, :name_id])
  end

  private

  def refuse_until_repaired
    duplicates = MigrationNameTracker.group(:user_id, :name_id).
                 having(Arel.star.count.gt(1)).count
    return if duplicates.empty?

    raise(<<~MESSAGE)
      #{duplicates.size} user/Name pairs have more than one tracker, so the
      unique index cannot be added yet.

      Run the repair first, reading its dry run before applying it:
        #{REPAIR.sub(" --apply", "")}
        #{REPAIR}
    MESSAGE
  end
end
