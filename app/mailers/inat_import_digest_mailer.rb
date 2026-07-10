# frozen_string_literal: true

# One digest per interested user, summarizing the observations an iNat
# import added that match names they follow. Sent once at the end of an
# import instead of a NameProposalMailer/NamingTrackerMailer for every
# imported naming — the batching that keeps a large import from flooding
# the mail queue. See #4757.
class InatImportDigestMailer < ApplicationMailer
  def build(receiver:, namings:)
    setup_user(receiver)
    count = namings.map(&:observation_id).uniq.size
    subject = :email_subject_inat_import_digest.l(count: count)
    debug_log(:inat_import_digest, nil, receiver, count: count.to_s)
    mo_mail(subject, to: receiver,
                     view_params: { subject:, receiver:, namings: })
  end
end
