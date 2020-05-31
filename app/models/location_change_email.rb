# frozen_string_literal: true

# Notify user of change in location description.
class LocationChangeEmail < AccountMailer
  def build(sender, receiver, time, loc_change, desc_change)
    setup_user(receiver)
    name = loc_change.old_clone.display_name
    @title = :email_subject_location_change.l(name: name)
    @sender = sender
    @time = time
    @loc_change = loc_change
    @desc_change = desc_change
    debug_log(:location_change, sender, receiver,
              location: loc_change.object, description: desc_change.object)
    mo_mail(@title, to: receiver)
  end
end
