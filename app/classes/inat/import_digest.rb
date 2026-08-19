# frozen_string_literal: true

class Inat
  # Builds and sends one digest email per interested user for a completed
  # iNat import, in place of the per-naming notifications that were
  # suppressed while the import ran (see Naming.suppress_notifications).
  # Reuses Naming#notified_user_ids so the digest reaches exactly the users
  # the per-naming emails would have. See #4757.
  class ImportDigest
    def self.deliver_for(inat_import)
      new(inat_import).deliver
    end

    # Caps a single digest's namings so the mailer's ActiveJob arguments
    # (a GlobalID per Naming, serialized into solid_queue_jobs.arguments)
    # stay well under MySQL's 65,535-byte TEXT column limit -- an import
    # with enough interested-user namings overflowed it, raising
    # Trilogy::ProtocolError 1406 and silently dropping every digest
    # after the offending one in iteration order (issue #5129).
    MAX_DIGEST_OBSERVATIONS = 500

    def initialize(inat_import)
      @inat_import = inat_import
    end

    def deliver
      namings_by_user.each { |user, namings| deliver_one(user, namings) }
    end

    private

    # Isolated per user so one failure (oversized args or otherwise)
    # can't abort the rest of the loop the way an unrescued exception
    # inside `each` would.
    def deliver_one(user, namings)
      by_observation = namings.group_by(&:observation_id)
      total = by_observation.size
      capped = capped_namings(by_observation)
      log_truncation(user, total) if capped.size < total

      InatImportDigestMailer.build(
        receiver: user, namings: capped, total_observations: total
      ).deliver_later
    rescue StandardError => e
      Rails.logger.error(
        "InatImportDigestMailer enqueue failed for user #{user.id} " \
        "(inat_import #{@inat_import.id}): #{e.class}: #{e.message}"
      )
    end

    # Keeps whole observations intact -- never splits one observation's
    # namings across the cap -- trimming from the end once the cap is hit.
    def capped_namings(by_observation)
      if by_observation.size <= MAX_DIGEST_OBSERVATIONS
        return by_observation.values.flatten
      end

      by_observation.first(MAX_DIGEST_OBSERVATIONS).flat_map { |_id, ns| ns }
    end

    def log_truncation(user, total)
      Rails.logger.warn(
        "InatImportDigestMailer: truncating digest for user #{user.id} " \
        "from #{total} to #{MAX_DIGEST_OBSERVATIONS} observations " \
        "(inat_import #{@inat_import.id})"
      )
    end

    # { User => [Naming, ...] } for the import's namings, keyed by the users
    # each naming would have notified, minus anyone who opted out of email.
    def namings_by_user
      by_uid = group_namings_by_uid
      users = User.where(id: by_uid.keys).index_by(&:id)
      by_uid.filter_map do |uid, namings|
        user = users[uid]
        [user, namings] if user && !user.no_emails
      end.to_h
    end

    def group_namings_by_uid
      by_uid = Hash.new { |hash, uid| hash[uid] = [] }
      import_namings.each do |naming|
        naming.notified_user_ids.each { |uid| by_uid[uid] << naming }
      end
      by_uid
    end

    def import_namings
      Naming.joins(:observation).
        where(observations: { inat_import_id: @inat_import.id }).
        includes(:observation, :name)
    end
  end
end
