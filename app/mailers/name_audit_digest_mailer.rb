# frozen_string_literal: true

# One end-of-run digest per affected user listing the names whose
# classification was changed by the classification audit script.
# See issue #4169.
class NameAuditDigestMailer < ApplicationMailer
  def build(receiver:, name_ids:, audit_date:)
    setup_user(receiver)
    @names = Name.where(id: name_ids).order(:text_name).to_a
    @audit_date = audit_date
    @title = :email_subject_name_audit_digest.l(count: @names.size)
    debug_log(:name_audit_digest, nil, receiver,
              audit_date: audit_date.to_s, count: @names.size.to_s)
    mo_mail(@title, to: receiver)
  end
end
