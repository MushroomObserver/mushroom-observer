# encoding: utf-8

# Conference Event Registration Email
class QueuedEmail::UpdateRegistration < QueuedEmail
  def registration; get_object(:registration, ::ConferenceRegistration); end
  def before;       get_string(:before);     end

  def self.create_email(receiver, registration, before)
    result = create(nil, receiver)
    raise "Missing regisration!" if !registration
    result.add_integer(:registration, registration.id)
    result.add_string(:before, before)
    result.finish
    return result
  end
  
  def deliver_email
    UpdateRegistrationEmail.build(to_user, registration, before).deliver
  end
end
