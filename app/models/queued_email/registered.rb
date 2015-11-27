# encoding: utf-8

# Conference Event Registration Email
class QueuedEmail::Registered < QueuedEmail
  def registration
    get_object(:registration, ::ConferenceRegistration)
  end

  def self.create_email(receiver, registration)
    result = create(nil, receiver)
    fail "Missing regisration!" unless registration
    result.add_integer(:registration, registration.id)
    result.finish
    result
  end

  def deliver_email
    RegistrationEmail.build(to_user, registration).deliver_now
  end
end
