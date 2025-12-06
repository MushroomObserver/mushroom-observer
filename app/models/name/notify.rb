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

    content = WebmasterMailer.prepend_user(user,
                                           "#{MO.http_domain}/names/#{id}")
    WebmasterMailer.build(
      sender_email: user.email,
      subject: "#{user.login} created #{user_real_text_name(user)}",
      content: content
    ).deliver_later
  end

  # This is called after saving potential changes to a Name.  It will determine
  # if the changes are important enough to notify the authors, and do so.
  def notify_users
    return if skip_notify
    return unless saved_version_changes?

    # debugger unless @current_user
    sender = @current_user || User.current
    recipients = []

    notify_admins(recipients)
    notify_authors(recipients)
    notify_editors(recipients)
    notify_reviewers(recipients)
    notify_interested(recipients)

    # Remove users who have opted out of all emails.
    recipients.reject!(&:no_emails)

    send_name_change_emails(sender, recipients)
  end

  def send_name_change_emails(sender, recipients)
    # Migrated from QueuedEmail::NameChange to deliver_later.
    # Calculate versions now while saved_changes? is still accurate.
    old_name_ver = saved_changes? ? version - 1 : version

    (recipients.uniq - [sender]).each do |recipient|
      NameChangeMailer.build(
        sender:, receiver: recipient, name: self,
        old_name_ver:, new_name_ver: version,
        description: nil, old_desc_ver: 0, new_desc_ver: 0,
        review_status: "no_change"
      ).deliver_later
    end
  end

  # Tell admins of the change.
  def notify_admins(recipients)
    descriptions.map(&:admins).each do |user_list|
      user_list.each do |user|
        recipients.push(user) if user.email_names_admin
      end
    end
  end

  # Tell authors of the change.
  def notify_authors(recipients)
    descriptions.map(&:authors).each do |user_list|
      user_list.each do |user|
        recipients.push(user) if user.email_names_author
      end
    end
  end

  # Tell editors of the change.
  def notify_editors(recipients)
    descriptions.map(&:editors).each do |user_list|
      user_list.each do |user|
        recipients.push(user) if user.email_names_editor
      end
    end
  end

  # Tell reviewers of the change.
  def notify_reviewers(recipients)
    descriptions.map(&:reviewer).each do |user|
      recipients.push(user) if user&.email_names_reviewer
    end
  end

  # Send to people who have registered interest.
  # Also remove everyone who has explicitly said they are NOT interested.
  def notify_interested(recipients)
    interests.each do |interest|
      if interest.state
        recipients.push(interest.user)
      else
        recipients.delete(interest.user)
      end
    end
  end
end
