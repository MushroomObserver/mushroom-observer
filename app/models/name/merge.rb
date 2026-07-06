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

      Name.transaction do
        move_observations(old_name)
        move_namings(old_name)
        move_mispellings(user, old_name)
        move_followings(old_name) # move Interest and Tracking
        move_descriptions(user, old_name)
        move_versions(old_name)
        move_nomenclature_attributes(old_name)
        move_taxonomy_attributes(user, old_name)

        # Re-snapshot right before destroying: a concurrent request
        # could have pointed a different Name's correct_spelling at
        # old_name after move_mispellings' query ran above. A plain
        # `Name.where` bypasses old_name's own association reader
        # entirely, so it neither triggers a StrictLoadingViolationError
        # (old_name.misspellings may already be eager-loaded via
        # Name.merge_includes) nor requires old_name.reload (which
        # would also wipe out move_descriptions' in-memory
        # `rss_log = nil`, un-orphaning it and causing do_log_destroy
        # to log a duplicate destroy entry). Catches anything that
        # slipped in during the merge, keeping correct_spelling_id
        # from ever dangling once old_name is gone.
        #
        # This still isn't watertight: nothing stops another
        # transaction from pointing correct_spelling_id at old_name
        # after this re-snapshot but before this transaction commits -
        # that needs a DB-level constraint (FK with ON DELETE
        # SET NULL/RESTRICT), not application code. Tracked as a
        # follow-up rather than expanding this PR into a migration.
        stragglers = Name.where(correct_spelling_id: old_name.id)
        move_mispellings(user, old_name, misspellings: stragglers)

        old_name.destroy!
      end
    end

    #######################

    private

    def move_observations(old_name)
      old_name.observations.each do |obs|
        obs.name = self
        obs.save!
      end
    end

    def move_namings(old_name)
      old_name.namings.each do |name|
        name.name = self
        name.save!
      end
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

    def move_followings(old_name)
      # Move over any interest in the old name.
      Interest.where(
        target_type: "Name", target_id: old_name.id
      ).find_each do |int|
        int.target = self
        int.save!
      end

      # Move over any notifications on the old name.
      NameTracker.where(name: old_name).update_all(name_id: id)
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
