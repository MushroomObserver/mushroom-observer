# encoding: utf-8
#
#  = Add Specimen Not Curator Email
#
#  This email is sent whenever a specimen is for an herbarium by someone who is not a curator of that herbarium.
#  It is sent to:
#
#  1. the herbarium curators
#
#  == Associated data
#
#  specimen:: integer, refers to a Specimen id
#
#  == Class methods
#
#  create_email:: Creates new email.
#
#  == Instance methods
#
#  observation::    Get instance of Specimen.
#  deliver_email::  Deliver via AccountMailer#deliver_add_specimen_not_curator.
#
################################################################################

class QueuedEmail::AddSpecimenNotCurator < QueuedEmail
  def specimen; get_object(:specimen, ::Specimen);   end

  def self.create_email(sender, recipient, specimen)
    result = create(sender, recipient)
    raise "Missing specimen!" if !specimen
    result.add_integer(:specimen, specimen.id)
    result.finish
    return result
  end

  def deliver_email
    # Make sure it hasn't been deleted since email was queued.
    if specimen
      AccountMailer.deliver_add_specimen_not_curator(user, to_user, specimen)
    end
  end
end
