# frozen_string_literal: true

# Aggregates end-of-run recipients for classification changes made by
# the classification audit script (#4169). Mirrors the recipient
# logic in `Name#notify_users` (admins, authors, editors, reviewers,
# interested users; honors per-role opt-outs and `no_emails`) but
# emits one digest per user across the whole run instead of one
# email per name per recipient.
class NameAuditDigest
  # Returns Hash { user_id => Set[name_id] } of users who should
  # receive a digest summarizing the audit's classification changes.
  # Excludes `sender`. Honors per-role email_names_* flags and the
  # global `no_emails` flag. A "not interested" Interest row removes
  # the user only for that name (matching `notify_users`).
  def self.recipients(name_ids:, sender:)
    name_ids = Array(name_ids).map(&:to_i).uniq
    return {} if name_ids.empty?

    positive = []
    negative = Set.new
    Name.where(id: name_ids).find_each do |name|
      collect_description_recipients(name, positive)
      collect_interest_pairs(name, positive, negative)
    end
    build_user_to_names(positive, negative, sender&.id)
  end

  # Sends one digest email per recipient via `deliver_later`. Returns
  # the number of emails enqueued.
  def self.send_digests(name_ids:, sender:, audit_date: Time.zone.now)
    rec = recipients(name_ids: name_ids, sender: sender)
    rec.each do |uid, nids|
      user = User.find(uid)
      NameAuditDigestMailer.build(
        receiver: user, name_ids: nids.to_a, audit_date: audit_date
      ).deliver_later
    end
    rec.size
  end

  def self.collect_description_recipients(name, positive)
    name.descriptions.each do |desc|
      add_role_pairs(desc.admins, name.id, positive, :email_names_admin)
      add_role_pairs(desc.authors, name.id, positive, :email_names_author)
      add_role_pairs(desc.editors, name.id, positive, :email_names_editor)
      reviewer = desc.reviewer
      positive << [reviewer.id, name.id] if reviewer&.email_names_reviewer
    end
  end

  def self.add_role_pairs(users, name_id, positive, flag)
    users.each { |u| positive << [u.id, name_id] if u.public_send(flag) }
  end

  def self.collect_interest_pairs(name, positive, negative)
    name.interests.each do |interest|
      if interest.state
        positive << [interest.user_id, name.id]
      else
        negative << [interest.user_id, name.id]
      end
    end
  end

  def self.build_user_to_names(positive, negative, sender_id)
    map = positive.each_with_object({}) do |(uid, nid), acc|
      next if uid == sender_id
      next if negative.include?([uid, nid])

      (acc[uid] ||= Set.new) << nid
    end
    return map if map.empty?

    no_email_ids = User.where(id: map.keys, no_emails: true).pluck(:id).to_set
    map.except(*no_email_ids)
  end
  private_class_method :collect_description_recipients, :add_role_pairs,
                       :collect_interest_pairs, :build_user_to_names
end
