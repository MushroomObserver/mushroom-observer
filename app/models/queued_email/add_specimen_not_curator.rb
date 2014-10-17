# encoding: utf-8

# Add Specimen Not Curator Email
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
      AddSpecimenEmail.build(user, to_user, specimen).deliver
    end
  end
end
