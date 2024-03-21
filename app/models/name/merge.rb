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
    def merge(old_name)
      return if old_name == self

      move_observations(old_name)
      move_namings(old_name)
      move_mispellings(old_name)
      move_followings(old_name) # move Interest and Tracking
      move_descriptions(old_name)
      move_versions(old_name)
      move_nomenclature_attributes(old_name)
      move_taxonomy_attributes(old_name)

      old_name.destroy
    end

    #######################

    private

    def move_observations(old_name)
      old_name.observations.each do |obs|
        obs.name = self
        obs.save
      end
    end

    def move_namings(old_name)
      old_name.namings.each do |name|
        name.name = self
        name.save
      end
    end

    def move_mispellings(old_name)
      old_name.misspellings.each do |name|
        name.correct_spelling = (name == self ? nil : self)
        name.save
      end
    end

    def move_followings(old_name)
      # Move over any interest in the old name.
      Interest.where(
        target_type: "Name", target_id: old_name.id
      ).find_each do |int|
        int.target = self
        int.save
      end

      # Move over any notifications on the old name.
      NameTracker.where(name: old_name).update_all(name_id: id)
    end

    def move_descriptions(old_name)
      move_primary_description(old_name)
      # Move over any remaining descriptions.
      NameDescription.where(name_id: old_name.id).update_all(name_id: id)

      # Log the action.
      old_name.rss_log&.orphan(old_name.display_name, :log_name_merged,
                               this: old_name.display_name, that: display_name)
      old_name.rss_log = nil
    end

    def move_primary_description(old_name)
      return unless !description && old_name.description

      # Move old_name's description to self if self lacks one
      self.description = old_name.description
      # Update the classification cache if that changed in the process.
      if description &&
         (classification != description.classification)
        self.classification = description.classification
      end
    end

    def move_versions(old_name)
      editors = old_name.versions.each_with_object([]) do |ver, e|
        e << ver.user_id
      end
      editors.delete(old_name.user_id)
      editors.uniq.each do |user_id|
        UserStats.update_contribution(:del, :name_versions, user_id)
      end

      old_name.versions.each(&:destroy)
    end

    def move_nomenclature_attributes(old_name)
      self.icn_id = old_name.icn_id if icn_id.blank?
      return unless citation.blank? && old_name.citation.present?

      self.citation = old_name.citation.strip_squeeze
    end

    def move_taxonomy_attributes(old_name)
      return unless old_name.has_notes? && (old_name.notes != notes)

      notes << "\n\n" if has_notes?
      self.notes += "These notes come from #{old_name.format_name} " \
                    "when it was merged with this name:\n\n #{old_name.notes}"

      log(:log_name_updated, touch: true)
      save
    end
  end
end
