# frozen_string_literal: true

# Notify user someone has observed a name they are interested in.
class NamingTrackerEmail < AccountMailer
  def build(tracker, naming)
    setup_user(tracker)
    name = "#{naming.observation_id}: #{naming.name.real_search_name}"
    @title = :email_subject_naming_for_tracker.l(name: name)
    @observation = naming.observation
    @naming = naming
    debug_log(:naming_for_observer, nil, tracker,
              naming: naming, observation: naming.observation)
    mo_mail(@title, to: tracker)
  end
end
