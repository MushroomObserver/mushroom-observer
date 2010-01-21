################################################################################
#
#  = Feature Email
#
#  This email is sent whenever the admin pushes out a new release, informing
#  all the users of the changes.  Everyone with User#email_feature enabled will
#  receive this. 
#
#  == Associated data
#
#  note::    variable-length text, contains description of changes
#
#  == Class methods
#
#  create_email::   Create new email.
#
#  == Instance methods
#
#  content::        Get description of changes.
#  deliver_email::  Deliver via AccountMailer#deliver_email_features.
#
################################################################################

class QueuedEmail::Feature < QueuedEmail
  def content; get_note; end

  def self.create_email(receiver, content)
    result = create(nil, receiver)
    raise "Missing content!" if !content
    result.set_note(content)
    result.finish
    return result
  end
  
  def deliver_email
    if to_user.email_general_feature # Make sure it hasn't changed
      AccountMailer.deliver_email_features(to_user, content)
    end
  end
end
