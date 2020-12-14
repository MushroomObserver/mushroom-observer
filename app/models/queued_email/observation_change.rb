# frozen_string_literal: true

# Observation Change Email
class QueuedEmail::ObservationChange < QueuedEmail
  def observation
    get_object(:observation, ::Observation)
  end

  def note
    get_note
  end

  # This should be called when changes are made directly to observation.
  def self.change_observation(sender, recipient, observation)
    changes = []
    changes.push("date")      if observation.saved_change_to_when?
    changes.push("location")  if observation.saved_change_to_place?
    changes.push("notes")     if observation.saved_change_to_notes?
    changes.push("specimen")  if observation.saved_change_to_specimen?
    if observation.saved_change_to_is_collection_location?
      changes.push("is_collection_location")
    end
    if observation.saved_change_to_thumb_image_id?
      changes.push("thumb_image_id")
    end

    if (email = find_email(recipient, observation))
      email.add_to_note_list(changes) if email.observation
    else
      email = create(sender, recipient)
      raise("Missing observation!") unless observation

      email.add_integer(:observation, observation.id)
      email.add_to_note_list(changes)
      email.finish
    end
    email
  end

  # This should be called when an observation is destroyed.
  def self.destroy_observation(sender, recipient, observation)
    note = observation.unique_format_name
    if (email = find_email(recipient, observation))
      email.add_integer(:observation, 0)
      email.set_note(note)
    else
      email = create(sender, recipient)
      email.add_integer(:observation, 0)
      email.set_note(note)
      email.finish
    end
    email
  end

  # This should be called when images are added or removed from an observation.
  # The "action" parameter should be either :added_image or :removed_image.
  def self.change_images(sender, recipient, observation, action)
    if (email = find_email(recipient, observation))
      email.add_to_note_list([action]) if email.observation
    else
      email = create(sender, recipient)
      raise("Missing observation!") unless observation

      email.add_integer(:observation, observation.id)
      email.add_to_note_list([action])
      email.finish
    end
    email
  end

  def deliver_email
    ObservationChangeEmail.build(user, to_user, observation, note, queued).
      deliver_now
  end

  ##############################################################################

  # private class methods

  # Check to see if there is already an email started.
  def self.find_email(recipient, observation)
    QueuedEmail.
      includes(:queued_email_integers).
      find_by("queued_emails.flavor" => "QueuedEmail::ObservationChange",
              "queued_email_integers.key" => "observation",
              "queued_emails.to_user_id" => recipient.id,
              "queued_email_integers.value" => observation.id)
  end

  private_class_method :find_email
end
