# frozen_string_literal: true

# Notify user of change in observation.
class ObservationChangeEmail < AccountMailer
  def build(sender, receiver, obs, note, time)
    setup_user(receiver)
    @title = observation_change_title(obs, note)
    @sender = sender
    @observation = obs
    @note = note
    @time = time
    debug_log(:observation_change, sender, receiver, observation: obs)
    mo_mail(@title, to: receiver)
  end

  private

  # TODO: Translation keys really shouldn't be this long (32).
  def observation_change_title(obs, note)
    if obs
      :email_subject_observation_change.l(name: obs.unique_text_name) if obs
    else
      :email_subject_observation_destroy.l(name: note).t.html_to_ascii
    end
  end
end
