# frozen_string_literal: true

# Tells a user once about a Name merge that moved namings they follow or a
# name they tracked. See Name::MergeDigest.
class NameMergeDigestMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  # merge: { sender: User who merged, old_name: the merged-away name's
  #          search_name (the Name is destroyed), new_name: surviving Name }
  def build(receiver:, merge:, namings: [], total_observations: nil,
            tracker_moved: false)
    setup_user(receiver)
    new_name = merge[:new_name]
    subject = :email_subject_name_merge_digest.l(old: merge[:old_name],
                                                 new: new_name.search_name)
    debug_log(:name_merge_digest, merge[:sender], receiver, name: new_name)
    mo_mail(subject, to: receiver,
                     view_params: {
                       subject:, receiver:, **merge, namings:, tracker_moved:,
                       total_observations: total_observations ||
                         namings.map(&:observation_id).uniq.size
                     })
  end
end
