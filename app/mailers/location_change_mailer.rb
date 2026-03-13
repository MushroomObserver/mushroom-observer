# frozen_string_literal: true

# Notify user of change in location description.
class LocationChangeMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  # Refactored to accept serializable arguments for deliver_later compatibility.
  # ObjectChange instances are constructed here from the IDs and versions.
  def build(**args)
    args => { sender:, receiver:, location:, old_loc_ver:, new_loc_ver:,
              description:, old_desc_ver:, new_desc_ver: }
    setup_user(receiver)
    @loc_change = ObjectChange.new(location, old_loc_ver, new_loc_ver)
    @desc_change = ObjectChange.new(description, old_desc_ver, new_desc_ver)
    name = @loc_change.old_clone&.display_name || location&.display_name
    @title = :email_subject_location_change.l(name: name)
    @sender = sender
    @time = location&.updated_at || Time.zone.now
    debug_log(:location_change, sender, receiver,
              location: location, description: description)
    mo_mail(@title, to: receiver)
  end
end
