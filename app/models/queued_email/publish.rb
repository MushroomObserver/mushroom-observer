# encoding: utf-8
#
#  = Name Published Email
#
#  This email is sent whenever someone publishes a draft name.  This is sent
#  to... reviewers only?  That is, users in the "reviewers" UserGroup.
#
#  == Associated data
#
#  name::    integer, refers to a Name id
#
#  == Class methods
#
#  create_email:: Create new email.
#
#  == Instance methods
#
#  name::           Get instance of Name in question.
#  deliver_email::  Deliver via AccountMailer#deliver_publish_name.
#
################################################################################

class QueuedEmail::Publish < QueuedEmail
  def name; get_object(:name, ::Name); end

  def self.create_email(publisher, receiver, name)
    result = create(publisher, receiver)
    raise "Missing name!" if !name
    result.add_integer(:name, name.id)
    result.finish
    return result
  end
  
  def deliver_email
    AccountMailer.deliver_publish_name(user, to_user, name)
  end
end
