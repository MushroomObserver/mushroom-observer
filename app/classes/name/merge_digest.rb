# frozen_string_literal: true

# One email per user about a Name merge, in place of the per-naming
# notifications Name#merge suppresses (Naming.suppress_notifications).
# A user hears once about every observation whose naming moved to the
# surviving name -- the users Naming#notified_user_ids names, less the
# user who merged -- and, if they tracked the merged-away name, that
# their tracker now follows the survivor. The trackers' notes to
# observers are not sent: a merge is not a new observation of the name.
class Name
  class MergeDigest
    MAX_OBSERVATIONS = Inat::ImportDigest::MAX_DIGEST_OBSERVATIONS

    attr_writer :naming_ids, :tracker_user_ids

    # old_name: the merged-away name's search_name, taken before the merge
    # destroys it.
    def initialize(merger:, survivor:, old_name:)
      @merger = merger
      @survivor = survivor
      @old_name = old_name
      @naming_ids = []
      @tracker_user_ids = []
    end

    def deliver
      users.each { |user| deliver_one(user) }
    end

    private

    # Isolated per user so one failure can't stop the rest.
    def deliver_one(user)
      NameMergeDigestMailer.build(**mail_args(user)).deliver_later
    rescue StandardError => e
      Rails.logger.error(
        "NameMergeDigestMailer enqueue failed for user #{user.id} " \
        "(name #{@survivor.id}): #{e.class}: #{e.message}"
      )
    end

    def mail_args(user)
      by_observation = namings_by_uid[user.id].group_by(&:observation_id)
      { receiver: user,
        merge: { sender: @merger, old_name: @old_name, new_name: @survivor },
        namings: by_observation.first(MAX_OBSERVATIONS).flat_map(&:last),
        total_observations: by_observation.size,
        tracker_moved: @tracker_user_ids.include?(user.id) }
    end

    def users
      ids = namings_by_uid.keys | @tracker_user_ids
      ids.delete(@merger&.id)
      User.where(id: ids).reject(&:no_emails)
    end

    def namings_by_uid
      @namings_by_uid ||= begin
                            by_uid = Hash.new { |hash, uid| hash[uid] = [] }
                            moved_namings.each do |naming|
                              naming.notified_user_ids(actor_id: @merger&.id).
                                each { |uid| by_uid[uid] << naming }
                            end
                            by_uid
                          end
    end

    def moved_namings
      Naming.where(id: @naming_ids).includes(:observation, :name).
        order(:observation_id)
    end
  end
end
