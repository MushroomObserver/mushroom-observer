# Notify email given in registration of a change in the registration
class UpdateRegistrationEmail < AccountMailer
  def build(user, registration, before)
    event = registration.conference_event
    setup_user(user)
    @registration = registration
    @before = before
    @title = :email_subject_update_registration.l(name: event.name)
    debug_log(:update_registration, nil, registration)
    mo_mail(@title, to: registration, from: MO.webmaster_email_address)
  end
end
