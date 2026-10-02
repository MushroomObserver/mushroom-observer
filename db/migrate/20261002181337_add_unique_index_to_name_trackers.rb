# frozen_string_literal: true

# Production and every local checkpoint hold duplicate trackers, so the
# cleanup runs here, ahead of the index, instead of in a run-once script.
class AddUniqueIndexToNameTrackers < ActiveRecord::Migration[7.2]
  class Tracker < ActiveRecord::Base
    self.table_name = "name_trackers"
  end

  class TrackerInterest < ActiveRecord::Base
    self.table_name = "interests"
  end

  def up
    remove_duplicate_trackers
    add_index(:name_trackers, [:user_id, :name_id], unique: true)
  end

  def down
    remove_index(:name_trackers, [:user_id, :name_id])
  end

  private

  def remove_duplicate_trackers
    duplicate_pairs.each do |user_id, name_id|
      keep, *extras = Tracker.where(user_id:, name_id:).sort_by do |tracker|
        keep_rank(tracker)
      end
      extra_ids = extras.map(&:id)
      TrackerInterest.where(target_type: "NameTracker",
                            target_id: extra_ids).delete_all
      Tracker.where(id: extra_ids).delete_all
      say("User #{user_id}, Name #{name_id}: kept tracker #{keep.id}, " \
          "removed #{extra_ids.join(", ")}")
    end
  end

  def duplicate_pairs
    Tracker.group(:user_id, :name_id).
      having(Tracker.arel_table[:id].count.gt(1)).
      pluck(:user_id, :name_id)
  end

  # Keep a tracker with a note template (approved first), else the oldest.
  def keep_rank(tracker)
    [tracker.note_template.present? ? 0 : 1, tracker.approved ? 0 : 1,
     tracker.id]
  end
end
