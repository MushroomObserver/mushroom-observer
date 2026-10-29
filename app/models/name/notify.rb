# frozen_string_literal: true

module Name::Notify
  attr_writer :skip_notify

  def skip_notify
    @skip_notify || false
  end

  # Notify webmaster that a new name was created.
  # Migrated from QueuedEmail::Webmaster to ActionMailer + ActiveJob.
  def notify_webmaster
    return if skip_notify

    message = WebmasterMailer.prepend_user(user,
                                           "#{MO.http_domain}/names/#{id}")
    WebmasterMailer.build(
      sender_email: user.email,
      subject: "#{user.login} created #{real_text_name(user)}",
      message:
    ).deliver_later
  end

  # This is called after saving potential changes to a Name.  It will determine
  # if the changes are important enough to notify the authors, and do so.
  def notify_users
    return if skip_notify
    return unless saved_version_changes?
    # Classification edits are system-curation rather than user-curation:
    # the propagate-to-subtaxa path uses update_all (no notifications),
    # and pre-#4163 the only notifying path was through NameDescription
    # — which most Names don't have. Now that classification is versioned
    # on Name itself (#4163), saving a classification change would fire
    # notify_users for every Name; preserve the prior user-facing behavior
    # by skipping notification when classification is the only versioned
    # column that changed.
    return if classification_only_change?

    sender = @current_user
    send_name_change_emails(sender,
                            finalize_recipients!(name_change_recipients,
                                                 sender))
  end

  def name_change_recipients
    recipients = []
    collect_role_recipients(
      [[descriptions.map(&:admins), :email_names_admin],
       [descriptions.map(&:authors), :email_names_author],
       [descriptions.map(&:editors), :email_names_editor],
       [descriptions.map(&:reviewer), :email_names_reviewer]],
      recipients
    )
    notify_interested(recipients)
    recipients
  end

  def send_name_change_emails(sender, recipients)
    # Migrated from QueuedEmail::NameChange to deliver_later.
    # Calculate versions now while saved_changes? is still accurate.
    old_name_ver = saved_changes? ? version - 1 : version

    recipients.each do |recipient|
      NameChangeMailer.build(
        sender:, receiver: recipient, name: self,
        old_name_ver:, new_name_ver: version,
        description: nil, old_desc_ver: 0, new_desc_ver: 0,
        review_status: "no_change"
      ).deliver_later
    end
  end

  # Send to people who have registered interest.
  # Also remove everyone who has explicitly said they are NOT interested.
  def notify_interested(recipients)
    Interest.update_recipients!(interests, recipients)
  end

  # True if classification was the only versioned column to change in
  # this save. Used to suppress notifications for classification-only
  # edits (manual edits, the inherit/propagate paths, and the
  # classification audit script).
  def classification_only_change?
    versioned_keys = self.class.versioned_columns.map(&:name)
    (saved_changes.keys & versioned_keys) == ["classification"]
  end
end
