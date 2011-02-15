# encoding: utf-8
#
#  = Location Change Email
#
#  This email is sent whenever someone changes a Location.  It is sent to:
#
#  1. the admins/authors/editors of the Location
#  2. anyone "interested in" the Location
#
#  == Associated data
#
#  location::                integer, refers to a Location id
#  description::             integer, refers to a LocationDescription id
#  old_location_version::    integer, Location version before the change
#  new_location_version::    integer, Location version after the change (may be the same!)
#  old_description_version:: integer, LocationDescription version before the change
#  new_description_version:: integer, LocationDescription version after the change (may be the same!)
#
#  == Class methods
#
#  create_email::   Create new email.
#
#  == Instance methods
#
#  location::                Get instance of Location in question.
#  description::             Get instance of LocationDescription in question.
#  old_location_version::    Get version of Location before change.
#  new_location_version::    Get version of Location after change (may be the same!)
#  old_description_version:: Get version of LocationDescription before change.
#  new_description_version:: Get version of LocationDescription after change (may be the same!)
#  deliver_email::           Deliver via AccountMailer#deliver_location_change.
#
################################################################################

class QueuedEmail::LocationChange < QueuedEmail
  def location;                get_object(:location, ::Location);     end
  def description;             get_object(:description, ::LocationDescription, :nil_okay); end
  def old_location_version;    get_integer(:old_location_version);    end
  def new_location_version;    get_integer(:new_location_version);    end
  def old_description_version; get_integer(:old_description_version); end
  def new_description_version; get_integer(:new_description_version); end

  def self.create_email(sender, recipient, location, desc=nil)
    result = create(sender, recipient)
    raise "Missing location or description!" if !location && !desc
    if location
      result.add_integer(:location, location.id)
      result.add_integer(:new_location_version, location.version)
      result.add_integer(:old_location_version, (location.altered? ? location.version - 1 : location.version))
    elsif location = desc.location
      result.add_integer(:location, location.id)
      result.add_integer(:new_location_version, location.version)
      result.add_integer(:old_location_version, location.version)
    end
    if desc
      result.add_integer(:description, desc.id)
      result.add_integer(:new_description_version, desc.version)
      result.add_integer(:old_description_version, (desc.altered? ? desc.version - 1 : desc.version))
    elsif desc = location.description
      result.add_integer(:description, desc.id)
      result.add_integer(:new_description_version, desc.version)
      result.add_integer(:old_description_version, desc.version)
    end
    result.finish
    return result
  end

  def deliver_email
    AccountMailer.deliver_location_change(user, to_user, queued, location,
      description, old_location_version, new_location_version,
      old_description_version, new_description_version)
  end
end
