# frozen_string_literal: true

require("test_helper")

module Observations
  class EmailsControllerTest < FunctionalTestCase
    include ActiveJob::TestHelper

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

    def test_access_form_turbo_stream
      obs = observations(:coprinus_comatus_obs)
      login
      get(:new, params: { id: obs.id }, format: :turbo_stream)
      assert_response(:success)
    end

    def test_send_observation_question
      obs = observations(:minimal_unknown_obs)
      params = {
        id: obs.id,
        question: {
          content: "Testing question"
        }
      }
      login
      assert_enqueued_with(
        job: ActionMailer::MailDeliveryJob,
        args: lambda { |args|
          args[0] == "ObserverQuestionMailer" && args[1] == "build"
        }
      ) do
        post(:create, params: params)
      end
      assert_redirected_to(observation_path(obs.id))
      assert_flash_text(:runtime_ask_observation_question_success.t)
    end

    def test_send_observation_question_turbo_stream
      obs = observations(:minimal_unknown_obs)
      params = {
        id: obs.id,
        question: { content: "Testing question" }
      }
      login
      assert_enqueued_with(
        job: ActionMailer::MailDeliveryJob,
        args: ->(args) { args[0] == "ObserverQuestionMailer" }
      ) do
        post(:create, params: params, format: :turbo_stream)
      end
      assert_response(:success)
      assert_flash_text(:runtime_ask_observation_question_success.t)
    end

    def test_send_observation_question_requires_content
      obs = observations(:minimal_unknown_obs)
      login

      assert_no_enqueued_jobs do
        post(:create, params: { id: obs.id, question: { content: "" } })
      end
      assert_flash_error
      assert_template(:new)
    end
  end
end
