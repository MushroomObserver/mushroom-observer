# encoding: utf-8

# Conference Event Registration Email
class QueuedEmail::Registered < QueuedEmail
  def registration; get_object(:registration, ::ConferenceRegistration); end

  def self.create_email(receiver, registration)
    result = create(nil, receiver)
    raise "Missing regisration!" if !registration
    result.add_integer(:registration, registration.id)
    result.finish
    return result
  end
  
  def deliver_email
    RegistrationEmail.build(to_user, registration).deliver
  end
end
