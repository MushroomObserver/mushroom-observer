class ObservationChangeEmail < BaseEmail
  attr_accessor :observation
  attr_accessor :note

  def initialize(email)
    id = email.get_integer(:observation)
    self.observation = id > 0 ? Observation.find(id) : nil
    self.note = email.get_note
    super(email)
  end

  # This should be called when changes are made directly to observation.
  def self.change_observation(sender, recipient, observation)
    changes = []
    changes.push('date')                   if observation.when_changed?
    changes.push('location')               if observation.location_id_changed? || observation.where_changed?
    changes.push('notes')                  if observation.notes_changed?
    changes.push('specimen')               if observation.specimen_changed?
    changes.push('is_collection_location') if observation.is_collection_location_changed?
    changes.push('thumb_image_id')         if observation.thumb_image_id_changed?
    if email = self.find_email(recipient, observation)
      if email.get_integer(:observation) != 0
        email.add_to_note_list(changes)
      end
    else
      email = QueuedEmail.new()
      email.setup(sender, recipient, :observation_change)
      email.save()
      email.add_integer(:observation, observation.id)
      email.add_to_note_list(changes)
      email.finish()
    end
    return email
  end

  # This should be called when an observation is destroyed.
  def self.destroy_observation(sender, recipient, observation)
    note = observation.unique_format_name
    if email = self.find_email(recipient, observation)
      email.add_integer(:observation, 0)
      email.set_note(note)
    else
      email = QueuedEmail.new()
      email.setup(sender, recipient, :observation_change)
      email.save()
      email.add_integer(:observation, 0)
      email.set_note(note)
      email.finish()
    end
    return email
  end

  # This should be called when images are added or removed from an observation.
  # The "action" parameter should be either :added_image or :removed_image.
  def self.change_images(sender, recipient, observation, action)
    if email = self.find_email(recipient, observation)
      if email.get_integer(:observation) != 0
        email.add_to_note_list([action])
      end
    else
      email = QueuedEmail.new()
      email.setup(sender, recipient, :observation_change)
      email.save()
      email.add_integer(:observation, observation.id)
      email.add_to_note_list([action])
      email.finish()
    end
    return email
  end

  # Check to see if there is already an email started.
  def self.find_email(recipient, observation)
    QueuedEmail.find(:first, :include => [:queued_email_integers],
      :conditions => [
        'queued_emails.to_user_id = ?' +
        ' and queued_emails.flavor = "observation_change"' +
        ' and queued_email_integers.key = "observation"' +
        ' and queued_email_integers.value = ?', recipient.id, observation.id])
  end

  def deliver_email
    if user == to_user
      print "Skipping email with same sender and recipient: #{user.email}\n" if !TESTING
    else
      AccountMailer.deliver_observation_change(user, to_user, observation, note, queued)
    end
  end
end
