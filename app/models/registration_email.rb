# Notify email given in registration of the registration
class RegistrationEmail < AccountMailer
  def build(user, registration)
    event = registration.conference_event
    setup_user(user)
    @registration = registration
    @title = :email_subject_registration.l(name: event.name)
    debug_log(:registration, nil, registration)
    mo_mail(@title, to: registration, from: MO.webmaster_email_address)
  end
end
