# frozen_string_literal: true

# Combine two Name objects (and associations) into one
module Name::Merge
  # Would merger into another Name destroy data in the sense that the
  # merger could not be uncrambled? If any information will get
  # lost we return true.
  # It is "destrutive" if: it has Namings, or if users have registered interest
  # in or otherwise requested notifications for this name. In some cases it will
  # be okay, but there are cases where users unintentionally end up subscribed
  # to notifications for every name in the database as a side-effect of merging
  # an unwanted name into Fungi, say. -JPH 20200120, - JDC 20201127
  def merger_destructive?
    namings.any? || interests.any?
  end

  # Merge all the stuff that refers to +old_name+ into +self+.  Usually, no
  # changes are made to +self+, however it might update the +classification+
  # cache if the old name had a better one -- NOT SAVED!!  Then +old_name+ is
  # destroyed; all the things that referred to +old_name+ are updated and
  # saved.
  def merge(old_name)
    return if old_name == self

    # Move all observations over to the new name.
    old_name.observations.each do |obs|
      obs.name = self
      obs.save
    end

    # Move all namings over to the new name.
    old_name.namings.each do |name|
      name.name = self
      name.save
    end

    # Move all misspellings over to the new name.
    old_name.misspellings.each do |name|
      name.correct_spelling = name == self ? nil : self
      name.save
    end

    # update any Interest and Tracking
    shift_followings(old_name)
    shift_descriptions(old_name)
    shift_versions(old_name)
    shift_nomenclature_attributes(old_name)
    shift_taxonomy_attributes(old_name)

    old_name.destroy
  end

  #######################

  private

  def shift_followings(old_name)
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

  def shift_descriptions(old_name)
    #     # Merge the two "main" descriptions if it can.
    #     if self.description and old_name.description and
    #        (self.description.source_type == :public) and
    #        (old_name.description.source_type == :public)
    #       self.description.merge(old_name.description, true)
    #     end

    # If this one doesn't have a primary description and the other does,
    # then make it this one's.
    if !description && old_name.description
      self.description = old_name.description
    end

    # Update the classification cache if that changed in the process.
    if description &&
       (classification != description.classification)
      self.classification = description.classification
    end

    # Move over any remaining descriptions.
    NameDescription.where(name_id: old_name.id).update_all(name_id: id)

    # Log the action.
    old_name.rss_log&.orphan(old_name.display_name, :log_name_merged,
                             this: old_name.display_name, that: display_name)
    old_name.rss_log = nil
  end

  def shift_versions(old_name)
    editors = old_name.versions.each_with_object([]) do |ver, e|
      e << ver.user_id
    end
    editors.delete(old_name.user_id)
    editors.uniq.each do |user_id|
      SiteData.update_contribution(:del, :names_versions, user_id)
    end

    old_name.versions.each(&:destroy)
  end

  def shift_nomenclature_attributes(old_name)
    self.icn_id = old_name.icn_id if icn_id.blank?
    return unless citation.blank? && old_name.citation.present?

    self.citation = old_name.citation.strip_squeeze
  end

  def shift_taxonomy_attributes(old_name)
    return unless old_name.has_notes? && (old_name.notes != notes)

    if has_notes?
      self.notes += "\n\nThese notes come from #{old_name.format_name} " \
                    "when it was merged with this name:\n\n #{old_name.notes}"
    else
      self.notes = old_name.notes
    end

    log(:log_name_updated, touch: true)
    save
  end
end
