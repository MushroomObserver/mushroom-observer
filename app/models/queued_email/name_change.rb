#
#  = Name Change Email
#
#  This email is sent whenever someone changes a Name.  It is sent to:
#
#  1. the owner of the Name
#  2. anyone "interested in" the Name
#
#  == Associated data
#
#  name::        integer, refers to a Name id
#  old_version:: integer, version before the change
#  new_version:: integer, version after the change (may be the same!)
#
#  == Class methods
#
#  create_email::   Create new email.
#
#  == Instance methods
#
#  name::           Get instance of Name in question.
#  old_version::    Get version of Name before change.
#  new_version::    Get version of Name after change (may be the same!)
#  deliver_email::  Deliver via AccountMailer#deliver_name_change.
#
################################################################################

class QueuedEmail::NameChange < QueuedEmail
  def name;          get_object(:name, ::Name);         end
  def old_version;   get_integer(:old_version);         end
  def new_version;   get_integer(:new_version);         end
  def review_status; get_string(:review_status).to_sym; end

  def self.create_email(sender, recipient, name, review_status_changed)
    result = create(sender, recipient)
    raise "Missing name!" if !name
    result.add_integer(:name, name.id)
    result.add_integer(:new_version, name.version)
    result.add_integer(:old_version, (name.altered? ? name.version - 1 : name.version))
    result.add_string(:review_status, review_status_changed ? name.review_status : :no_change)
    result.finish
    return result
  end

  def deliver_email
    AccountMailer.deliver_name_change(user, to_user, queued, name,
                                      old_version, new_version, review_status)
  end
end
