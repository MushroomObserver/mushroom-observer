# encoding: utf-8
#
#  = Conference Event Registration Email
#
#  This email is sent whenever someone registers for a conference event.  This is sent
#  to email address given in the registration.
#
#  == Associated data
#
#  registration::    integer, refers to a ConferenceRegistration id
#
#  == Class methods
#
#  create_email:: Create new email.
#
#  == Instance methods
#
#  registration::           Get instance of ConferenceRegistration in question.
#  deliver_email::  Deliver via AccountMailer#deliver_email_registration
#
################################################################################

class QueuedEmail::Registration < QueuedEmail
  def registration; get_object(:registration, ::ConferenceRegistration); end

  def self.create_email(receiver, registration)
    result = create(nil, receiver)
    raise "Missing regisration!" if !registration
    result.add_integer(:registration, registration.id)
    result.finish
    return result
  end
  
  def deliver_email
    AccountMailer.deliver_email_registration(to_user, registration)
  end
end
