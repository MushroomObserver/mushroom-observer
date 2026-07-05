# frozen_string_literal: true

# Notify user of change in name description.
class NameChangeMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  PERMISSION_REASONS = [
    ["editor", :email_names_editor, :editor?],
    ["author", :email_names_author, :author?],
    ["admin", :email_names_admin, :is_admin?],
    ["reviewer", :email_names_reviewer, :reviewer?]
  ].freeze

  # Refactored to accept serializable arguments for deliver_later compatibility.
  # ObjectChange instances are constructed here from the IDs and versions.
  def build(**args)
    args => { sender:, receiver:, name:, old_name_ver:, new_name_ver:,
              description:, old_desc_ver:, new_desc_ver:, review_status: }
    setup_user(receiver)
    name_change = ObjectChange.new(name, old_name_ver, new_name_ver)
    desc_change = ObjectChange.new(description, old_desc_ver, new_desc_ver)
    subject = :email_subject_name_change.l(name: calc_search_name(name_change,
                                                                  receiver))
    time = name.updated_at
    debug_log(:name_change, sender, receiver, name:, description:)
    mo_mail(subject, to: receiver,
                     view_params: { subject:, receiver:, sender:, time:,
                                    name_change:, desc_change:,
                                    review_status: calc_review_status(
                                      review_status
                                    ),
                                    watching: receiver.watching?(
                                      name_change.new_clone
                                    ),
                                    email_type: name_email_type(
                                      receiver, name_change, desc_change
                                    ) })
  end

  private

  def calc_review_status(status)
    :"review_#{status}".l if status != "no_change"
  end

  def calc_search_name(name_change, receiver)
    (name_change.old_clone || name_change.new_clone).
      user_real_search_name(receiver)
  end

  # "interest" / "editor" / "author" / "admin" / "reviewer" / nil —
  # why this receiver is being notified. Computed here (not in the
  # view; views shouldn't query the database) since editor?/author?/
  # is_admin?/reviewer? all query permission join tables (or the
  # reviewer association, for reviewer?). If notifiable for multiple
  # reasons, PERMISSION_REASONS' order decides which one wins:
  # interest first, then editor, author, admin, and lastly reviewer
  # (this matches the pre-Phlex ERB template's precedence exactly —
  # not revisited here since changing which reason gets reported
  # would change the "stop sending" link a multi-reason recipient
  # sees, a real behavior change outside this conversion's scope).
  def name_email_type(receiver, name_change, desc_change)
    new_name = name_change.new_clone
    old_name = name_change.old_clone
    return "interest" if receiver.watching?(new_name)

    if !old_name || new_name.version != old_name.version
      permission_reason(receiver, new_name.descriptions)
    elsif (new_desc = desc_change.new_clone)
      permission_reason(receiver, [new_desc])
    end
  end

  def permission_reason(receiver, descriptions)
    PERMISSION_REASONS.each do |reason, pref, predicate|
      next unless receiver.public_send(pref)
      next unless descriptions.any? { |d| d.public_send(predicate, receiver) }

      return reason
    end
    nil
  end
end
