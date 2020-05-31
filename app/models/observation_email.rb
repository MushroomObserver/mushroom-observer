# frozen_string_literal: true

# User asking user about an observation.
class ObservationEmail < AccountMailer
  def build(sender, observation, question)
    setup_user(observation.user)
    name = observation.unique_text_name
    @title = :email_subject_observation_question.l(name: name)
    @sender = sender
    @observation = observation
    @message = question || ""
    debug_log(:observation_question, sender, @user, observation: observation)
    mo_mail(@title, to: @user, reply_to: sender)
  end
end
