# encoding: utf-8
#
#  = Name Change Email
#
#  This email is sent whenever someone changes a Name.  It is sent to:
#
#  1. the admins/authors/editors/reviewers of the Name
#  2. anyone "interested in" the Name
#
#  == Associated data
#
#  name::                    integer, refers to a Name id
#  description::             integer, refers to a NameDescription id
#  old_name_version::        integer, Name version before the change
#  new_name_version::        integer, Name version after the change (may be the same!)
#  old_description_version:: integer, NameDescription version before the change
#  new_description_version:: integer, NameDescription version after the change (may be the same!)
#  review_status::           string,  'no_change' or new review status
#
#  == Class methods
#
#  create_email::   Create new email.
#
#  == Instance methods
#
#  name::                    Get instance of Name in question.
#  description::             Get instance of NameDescription in question.
#  old_name_version::        Get version of Name before change.
#  new_name_version::        Get version of Name after change (may be the same!)
#  old_description_version:: Get version of NameDescription before change.
#  new_description_version:: Get version of NameDescription after change (may be the same!)
#  deliver_email::           Deliver via AccountMailer#deliver_name_change.
#
################################################################################

class QueuedEmail::NameChange < QueuedEmail
  def name;                    get_object(:name, ::Name);             end
  def description;             get_object(:description, ::NameDescription,
                                          :allow_nil); end
  def old_name_version;        get_integer(:old_name_version);        end
  def new_name_version;        get_integer(:new_name_version);        end
  def old_description_version; get_integer(:old_description_version); end
  def new_description_version; get_integer(:new_description_version); end
  def review_status;           get_string(:review_status).to_sym;     end

  def self.create_email(sender, recipient, name, desc, review_status_changed)
    result = create(sender, recipient)
    raise "Missing name or description!" if !name && !desc
    if name
      result.add_integer(:name, name.id)
      result.add_integer(:new_name_version, name.version)
      result.add_integer(:old_name_version, (name.changed? ? name.version - 1 : name.version))
    else
      name = desc.name
      result.add_integer(:name, name.id)
      result.add_integer(:new_name_version, name.version)
      result.add_integer(:old_name_version, name.version)
    end
    if desc
      result.add_integer(:description, desc.id)
      result.add_integer(:new_description_version, desc.version)
      result.add_integer(:old_description_version, (desc.changed? ? desc.version - 1 : desc.version))
      result.add_string(:review_status, review_status_changed ? desc.review_status : :no_change)
    else
      result.add_integer(:description, 0)
      result.add_integer(:new_description_version, 0)
      result.add_integer(:old_description_version, 0)
      result.add_string(:review_status, :no_change)
    end
    result.finish
    return result
  end

  def deliver_email
    # Make sure name wasn't deleted or merged since email was queued.
    if name
      AccountMailer.deliver_name_change(user, to_user, queued, name, description,
        old_name_version, new_name_version, old_description_version,
        new_description_version, review_status)
    end
  end
end
