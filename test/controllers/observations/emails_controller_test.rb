# frozen_string_literal: true

require("test_helper")

module Observations
  class EmailsControllerTest < FunctionalTestCase
    def test_access_form
      obs = observations(:coprinus_comatus_obs)
      requires_login(:new, id: obs.id)
      assert_form_action(action: :create, id: obs.id)

      # Prove that it won't load the form for someone who has opted out
      # of all emails. Redirects to the obs.
      mary.update(no_emails: true)
      mary_obs = observations(:minimal_unknown_obs)
      requires_login(:new, id: mary_obs.id)
      assert_redirected_to(permanent_observation_path(mary_obs.id))
    end

    def test_send_observation_question
      obs = observations(:minimal_unknown_obs)
      params = {
        id: obs.id,
        question: {
          content: "Testing question"
        }
      }
      post_requires_login(:create, params)
      assert_redirected_to(observation_path(obs.id))
      assert_flash_text(:runtime_ask_observation_question_success.t)
    end
  end
end
