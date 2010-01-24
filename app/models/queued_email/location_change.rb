#
#  = Location Change Email
#
#  This email is sent whenever someone changes a Location.  It is sent to:
#
#  1. the owner of the Location
#  2. anyone "interested in" the Location
#
#  == Associated data
#
#  location::    integer, refers to a Location id
#  old_version:: integer, version before the change
#  new_version:: integer, version after the change (may be the same!)
#
#  == Class methods
#
#  create_email::   Create new email.
#
#  == Instance methods
#
#  location::       Get instance of Location in question.
#  old_version::    Get version of Location before change.
#  new_version::    Get version of Location after change (may be the same!)
#  deliver_email::  Deliver via AccountMailer#deliver_location_change.
#
################################################################################

class QueuedEmail::LocationChange < QueuedEmail
  def location;    get_object(:location, ::Location); end
  def old_version; get_integer(:old_version);         end
  def new_version; get_integer(:new_version);         end

  def self.create_email(sender, recipient, location)
    result = create(sender, recipient)
    raise "Missing location!" if !location
    result.add_integer(:location, location.id)
    result.add_integer(:new_version, location.version)
    result.add_integer(:old_version, (location.altered? ? location.version - 1 : location.version))
    result.finish
    return result
  end

  def deliver_email
    AccountMailer.deliver_location_change(user, to_user, queued, location,
                                          old_version, new_version)
  end
end
