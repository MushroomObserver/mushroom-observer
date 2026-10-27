# frozen_string_literal: true

# One run of ImagePurgeJob (#5521): deleting the images an MO user holds
# or an excluded iNat user's photos imported by anyone. The record is the
# job's progress, and while it is in flight it refuses a second purge of
# the same target.
#
#  user::                      Who started it.
#  target_user::               The MO user whose images go, or
#  inat_login::                the excluded iNat user's.
#  image_count::               Images the purge found.
#  deleted_image_count::       Images destroyed so far.
#  cleared_notes_count::       The target's MO-native observations whose
#                              notes were cleared.
#  placeholder_count::         Imported observations left as placeholders.
class ImagePurge < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :target_user, class_name: "User", optional: true

  enum :state, { pending: 0, running: 1, done: 2, failed: 3 }

  scope :in_progress, -> { where(state: [:pending, :running]) }

  validate :one_target

  def self.in_progress_for(target_user: nil, inat_login: nil)
    scope = in_progress
    scope = if target_user
              scope.where(target_user: target_user)
            else
              scope.where(inat_login: inat_login)
            end
    scope.order(:id).last
  end

  def plan
    ImagePurge::Plan.new(target_user: target_user, inat_login: inat_login)
  end

  private

  def one_target
    return if target_user_id.present? ^ inat_login.present?

    errors.add(:base, :image_purge_one_target)
  end
end
