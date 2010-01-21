################################################################################
#
#  = Observation Change Email
#
#  This email is sent whenever an Observation is changed.  There are several
#  cases in which this happens: 
#
#  1. when the observation is edited
#  2. when images are added or removed
#  3. when the observation is deleted
#
#  In practice, I think these only get sent to people "interested in" the
#  Observation in question.
#
#  == Associated data
#
#  observation::  integer, refers to an Observation id
#  note::         string, a list of attribute (names) that were changed
#
#  This is somewhat complicated, so it's worth explaining in more detail.
#
#  If the observation was destroyed:
#
#    observation = 0
#    note        = observation.unique_format_name
#
#  If the observation or images were changed:
#
#    observation = observation.id
#    note        = changes.join(",")
#
#  Where "changes" are any of these words (only one of each allowed):
#
#  "date"::                   Date was changed.
#  "location"::               Location was changed.
#  "notes"::                  Notes were changed.
#  "specimen"::               Is there a specimen? changed.
#  "is_collection_location":: Is this where it was collected? changed.
#  "thumb_image_id"::         The thumbnail changed.
#  "add_image"::              An image was added.
#  "removed_image"::          An image was removed.
#
#  == Class methods
#
#  change_observation::  Create/modify email after editing an observation.
#  change_images::       Create/modify email after adding/removing images.
#  destroy_observation:: Create/modify email after destroying an observation.
#
#  == Instance methods
#
#  observation::    Get instance of Observation that was changed.
#  note::           Get string of attributes that were changed.
#  deliver_email::  Deliver via AccountMailer#deliver_observation_change.
#
################################################################################

class QueuedEmail::ObservationChange < QueuedEmail
  def observation; get_object(:observation, ::Observation, :allow_nil); end
  def note; get_note; end

  # This should be called when changes are made directly to observation.
  def self.change_observation(sender, recipient, observation)
    changes = []
    changes.push('date')                   if observation.when_changed?
    changes.push('location')               if observation.location_id_changed? || observation.where_changed?
    changes.push('notes')                  if observation.notes_changed?
    changes.push('specimen')               if observation.specimen_changed?
    changes.push('is_collection_location') if observation.is_collection_location_changed?
    changes.push('thumb_image_id')         if observation.thumb_image_id_changed?
    if email = find_email(recipient, observation)
      email.add_to_note_list(changes) if email.observation
    else
      email = create(sender, recipient)
      raise "Missing observation!" if !observation
      email.add_integer(:observation, observation.id)
      email.add_to_note_list(changes)
      email.finish
    end
    return email
  end

  # This should be called when an observation is destroyed.
  def self.destroy_observation(sender, recipient, observation)
    note = observation.unique_format_name
    if email = find_email(recipient, observation)
      email.add_integer(:observation, 0)
      email.set_note(note)
    else
      email = create(sender, recipient)
      email.add_integer(:observation, 0)
      email.set_note(note)
      email.finish
    end
    return email
  end

  # This should be called when images are added or removed from an observation.
  # The "action" parameter should be either :added_image or :removed_image.
  def self.change_images(sender, recipient, observation, action)
    if email = find_email(recipient, observation)
      email.add_to_note_list([action]) if email.observation
    else
      email = create(sender, recipient)
      raise "Missing observation!" if !observation
      email.add_integer(:observation, observation.id)
      email.add_to_note_list([action])
      email.finish
    end
    return email
  end

  def deliver_email
    AccountMailer.deliver_observation_change(user, to_user, observation, note, queued)
  end

################################################################################

private

  # Check to see if there is already an email started.
  def self.find_email(recipient, observation)
    QueuedEmail.first(:include => :queued_email_integers,
      :conditions => [
        'queued_emails.to_user_id = ?' +
        ' and queued_emails.flavor = "QueuedEmail::ObservationChange"' +
        ' and queued_email_integers.key = "observation"' +
        ' and queued_email_integers.value = ?', recipient.id, observation.id])
  end
end
