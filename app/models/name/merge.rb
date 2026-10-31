# frozen_string_literal: true

# Combine two Name objects (and associations) into one
class Name
  module Merge
    # Would merger into another Name destroy data in the sense that the
    # merger could not be uncrambled? If any information will get
    # lost we return true.
    # It's "destrutive" if:
    # - has Namings, or
    # - users registered interest in or otherwise requested notifications f
    #   for this name. In some cases it will be okay,
    #   but there are cases where users unintentionally end up subscribed
    #   to notifications for every name in the db as a side-effect of merging
    #   an unwanted name into Fungi, say. -JPH 20200120, - JDC 20201127
    def merger_destructive?
      namings.any? || interests.any?
    end

    # Merge all the stuff that refers to old_name into self.
    # Usually, no changes are made to self attributes.
    # But it might the following if old_name had better ones:
    #  classification cache NOT SAVED!!
    #  icn_id
    #  citation
    # All things that referred to old_name are moved to self and saved.
    # Finally, +old_name+ destroyed.
    def merge(user, old_name)
      return if old_name == self

      digest = Name::MergeDigest.new(merger: user, survivor: self,
                                     old_name: old_name.search_name)
      Naming.suppress_notifications do
        merge_records(user, old_name, digest)
      end
      digest.deliver
    end

    #######################

    private

    def merge_records(user, old_name, digest)
      Name.transaction do
        move_observations(old_name)
        digest.naming_ids = move_namings(user, old_name)
        move_mispellings(user, old_name)
        digest.tracker_user_ids = move_followings(old_name)
        move_descriptions(user, old_name)
        move_versions(old_name)
        move_nomenclature_attributes(old_name)
        move_taxonomy_attributes(user, old_name)

        # Re-snapshot right before destroying: a concurrent request
        # could have pointed a different Name's correct_spelling at
        # old_name after move_mispellings' query ran above. A plain
        # `Name.where` bypasses old_name's association reader, so it
        # neither triggers StrictLoadingViolationError nor requires
        # old_name.reload (which would wipe out move_descriptions'
        # in-memory `rss_log = nil`). Not watertight: a transaction
        # could still point correct_spelling_id at old_name after
        # this snapshot but before commit -- that needs a DB-level
        # constraint, not application code.
        stragglers = Name.where(correct_spelling_id: old_name.id)
        move_mispellings(user, old_name, misspellings: stragglers)

        old_name.destroy!
      end
    end

    def move_observations(old_name)
      old_name.observations.each do |obs|
        obs.name = self
        obs.save!
      end
    end

    # Returns the ids of the namings re-pointed at self. An absorbed naming
    # is left out: its observation already had the surviving name.
    def move_namings(user, old_name)
      old_name.namings.filter_map do |naming|
        if (existing = duplicate_naming_for(naming))
          # This user already has a naming for the surviving name on this
          # observation, so re-pointing would duplicate it -- fold the two
          # into one instead (#5186).
          existing.current_user = user
          naming.current_user = user
          existing.absorb(naming)
          nil
        else
          naming.name = self
          naming.save!
          naming.id
        end
      end
    end

    # A naming by the same user for the surviving name (self) on the same
    # observation as `naming`, or nil.
    def duplicate_naming_for(naming)
      Naming.find_by(observation_id: naming.observation_id,
                     user_id: naming.user_id, name_id: id)
    end

    def move_mispellings(user, old_name, misspellings: old_name.misspellings)
      misspellings.each do |name|
        name.correct_spelling = (name == self ? nil : self)
        # `name` (a misspelling of old_name) is a different record from
        # `self`/old_name, so it never gets a `current_user` from
        # anywhere else in `merge` - without this, Name::Notify#notify_users
        # would attribute the resulting change-notification email to
        # no one instead of the user performing the merge.
        name.current_user = user
        name.save!
      end
    end

    # Moves Interests and NameTrackers to self; returns the user ids of the
    # moved trackers.
    def move_followings(old_name)
      # Move over any interest in the old name.
      Interest.where(
        target_type: "Name", target_id: old_name.id
      ).find_each do |int|
        int.target = self
        int.save!
      end

      # Move over any notifications on the old name.
      trackers = NameTracker.where(name: old_name)
      tracker_user_ids = trackers.pluck(:user_id)
      trackers.update_all(name_id: id)
      tracker_user_ids
    end

    def move_descriptions(user, old_name)
      move_primary_description(old_name)
      # Move over any remaining descriptions.
      NameDescription.where(name_id: old_name.id).update_all(name_id: id)

      # Log the action.
      old_name.rss_log&.orphan(user, old_name[:display_name], :log_name_merged,
                               this: old_name[:display_name],
                               that: self[:display_name])
      old_name.rss_log = nil
    end

    def move_primary_description(old_name)
      return unless !description && old_name.description

      # Move old_name's description to self if self lacks one.
      # The classification reconciliation that used to live here was
      # tied to `name_descriptions.classification` — which is gone
      # along with the column (discussion #4163). Classification stays
      # whatever `self.classification` already says.
      self.description = old_name.description
    end

    def move_versions(old_name)
      editors = old_name.versions.each_with_object([]) do |ver, e|
        e << ver.user_id
      end
      editors.delete(old_name.user_id)
      editors.uniq.each do |user_id|
        UserStats.update_contribution(:del, :name_versions, user_id)
      end

      old_name.versions.each(&:destroy!)
    end

    def move_nomenclature_attributes(old_name)
      self.icn_id = old_name.icn_id if icn_id.blank?
      return unless citation.blank? && old_name.citation.present?

      self.citation = old_name.citation.strip_squeeze
    end

    def move_taxonomy_attributes(user, old_name)
      return unless old_name.has_notes? && (old_name.notes != notes)

      prepare_notes_for_merger
      self.notes = "#{notes}These notes come from merge with " \
                   "#{old_name.format_name(@user)}:\n\n #{old_name.notes}"
      log(:log_name_updated, user: user, touch: true)
      @current_user = user
      save!
    end

    def prepare_notes_for_merger
      self.notes = if has_notes?
                     notes << "\n\n"
                   else
                     ""
                   end
    end
  end
end
