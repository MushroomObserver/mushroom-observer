class Name < AbstractModel
  # This is called after saving potential changes to a Name.  It will determine
  # if the changes are important enough to notify the authors, and do so.
  def notify_users
    return unless saved_version_changes?

    sender = User.current
    recipients = []

    # Tell admins of the change.
    descriptions.map(&:admins).each do |user_list|
      user_list.each do |user|
        recipients.push(user) if user.email_names_admin
      end
    end

    # Tell authors of the change.
    descriptions.map(&:authors).each do |user_list|
      user_list.each do |user|
        recipients.push(user) if user.email_names_author
      end
    end

    # Tell editors of the change.
    descriptions.map(&:editors).each do |user_list|
      user_list.each do |user|
        recipients.push(user) if user.email_names_editor
      end
    end

    # Tell reviewers of the change.
    descriptions.map(&:reviewer).each do |user|
      recipients.push(user) if user && user.email_names_reviewer
    end

    # Tell masochists who want to know about all name changes.
    User.where(email_names_all: true).each do |user|
      recipients.push(user)
    end

    # Send to people who have registered interest.
    # Also remove everyone who has explicitly said they are NOT interested.
    interests.each do |interest|
      if interest.state
        recipients.push(interest.user)
      else
        recipients.delete(interest.user)
      end
    end

    # Send notification to all except the person who triggered the change.
    (recipients.uniq - [sender]).each do |recipient|
      QueuedEmail::NameChange.create_email(sender, recipient, self, nil, false)
    end
  end
end
