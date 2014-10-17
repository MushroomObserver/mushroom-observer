# Notify user someone has observed a name they are interested in.
class NamingTrackerEmail < AccountMailer
  def build(tracker, naming)
    setup_user(tracker)
    @title = :email_subject_naming_for_tracker.l
    @observation = naming.observation
    @naming = naming
    debug_log(:naming_for_observer, nil, tracker,
              naming: naming, observation: naming.observation)
    mo_mail(@title, to: tracker)
  end
end
