# frozen_string_literal: true

# What iNaturalist answered when asked which taxon a target Name, or
# which place a target Location, corresponds to. One row per target,
# shared by every project targeting it.
#
# Three states, which `Inat::ConstraintMapper` reads as nil, false and an
# id. No row means the target has not been looked up. A row with no
# `inat_id` means iNaturalist answered and knew nothing -- worth saving,
# since it cost a lookup to establish, and not the same as an unanswered
# question, which pages report as "not all targets looked up".
#
# A row goes stale two ways, and a stale row reads as absent. The
# matching version moves when how MO matches a target changes, so a miss
# saved under the old rules is asked again. `target_updated_at` moves
# when the MO record does, since a renamed Name may match a different
# taxon.
#
# `checked_at` records when iNaturalist last confirmed the answer. It is
# what a scheduled re-confirmation orders by, and how far back it scans
# when an id turns out to have moved.
class InatTargetLookup < ApplicationRecord
  belongs_to :target, polymorphic: true

  validates :matching_version, presence: true
  validates :checked_at, presence: true

  # Longest unconfirmed first, which is the order a bounded daily
  # re-confirmation works in.
  scope :by_staleness, -> { order(:checked_at, :id) }

  class << self
    # The saved answer for this target under the current matching
    # rules: the iNat id, false when iNaturalist knew nothing, or nil
    # when there is nothing usable saved.
    def answer_for(target, version:)
      row = fresh_row(target, version)
      return nil unless row

      row.inat_id || false
    end

    # Saves what iNaturalist answered. `answer` is an id, or false for a
    # miss -- the same two values `answer_for` gives back.
    def record(target, answer, version:)
      row = find_or_initialize_by(target: target)
      row.update!(
        inat_id: answer || nil,
        matching_version: version,
        target_updated_at: target.updated_at,
        checked_at: Time.zone.now
      )
      row
    end

    private

    # A row written under older matching rules, or before the target was
    # last edited, is not an answer to the question being asked now.
    #
    # The timestamp compares with `<` rather than `!=`: a target saved in
    # memory carries more precision than the column keeps, so an
    # equality test would call a fresh row stale and ask iNaturalist
    # again on every read.
    def fresh_row(target, version)
      row = find_by(target: target, matching_version: version)
      return nil unless row
      return nil if row.target_updated_at < target.updated_at

      row
    end
  end
end
