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

    def initialize(inat_import)
      @inat_import = inat_import
    end

    def deliver
      namings_by_user.each do |user, namings|
        InatImportDigestMailer.build(receiver: user, namings: namings).
          deliver_later
      end
    end

    private

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
