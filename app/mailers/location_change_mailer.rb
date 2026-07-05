# frozen_string_literal: true

# Notify user of change in location description.
class LocationChangeMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  PERMISSION_REASONS = [
    ["editor", :email_locations_editor, :editor?],
    ["author", :email_locations_author, :author?],
    ["admin", :email_locations_admin, :is_admin?]
  ].freeze

  # Refactored to accept serializable arguments for deliver_later compatibility.
  # ObjectChange instances are constructed here from the IDs and versions.
  def build(**args)
    args => { sender:, receiver:, location:, old_loc_ver:, new_loc_ver:,
              description:, old_desc_ver:, new_desc_ver: }
    setup_user(receiver)
    loc_change = ObjectChange.new(location, old_loc_ver, new_loc_ver)
    desc_change = ObjectChange.new(description, old_desc_ver, new_desc_ver)
    name = loc_change.old_clone&.display_name || location&.display_name
    subject = :email_subject_location_change.l(name: name)
    time = location&.updated_at || Time.zone.now
    debug_log(:location_change, sender, receiver, location:, description:)
    mo_mail(subject, to: receiver,
                     view_params: { subject:, receiver:, sender:, time:,
                                    loc_change:, desc_change:,
                                    watching: receiver.watching?(
                                      loc_change.new_clone
                                    ),
                                    email_type: location_email_type(
                                      receiver, loc_change, desc_change
                                    ) })
  end

  private

  # "interest" / "editor" / "author" / "admin" / nil — why this
  # receiver is being notified. Computed here (not in the view; views
  # shouldn't query the database) since editor?/author?/is_admin? all
  # query permission join tables. If notifiable for multiple reasons,
  # PERMISSION_REASONS' order decides which one wins: interest first,
  # then editor, author, and lastly admin (this matches the pre-Phlex
  # ERB template's precedence exactly — not revisited here since
  # changing which reason gets reported would change the "stop
  # sending" link a multi-reason recipient sees, a real behavior
  # change outside this conversion's scope).
  def location_email_type(receiver, loc_change, desc_change)
    new_loc = loc_change.new_clone
    old_loc = loc_change.old_clone
    return "interest" if receiver.watching?(new_loc)

    if new_loc.version != old_loc.version
      permission_reason(receiver, new_loc.descriptions)
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
