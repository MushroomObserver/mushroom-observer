# frozen_string_literal: true

require("test_helper")

module Users
  class EmailsControllerTest < FunctionalTestCase
    include ActiveJob::TestHelper

    def test_ask_questions
      id = mary.id
      requires_login(:new, id: id)
      assert_form_action(action: :create, id: id)

      # Prove that trying to ask question of user who refuses questions
      # redirects to that user's page (instead of an email form).
      user = users(:no_general_questions_user)
      requires_login(:new, id: user.id)
      assert_flash_text(:permission_denied.t)

      # Prove that it won't email someone who has opted out of all emails.
      mary.update(no_emails: true)
      requires_login(:new, id: mary.id)
      assert_flash_text(:permission_denied.t)
    end

    def test_send_user_question
      params = {
        id: mary.id,
        user_question: {
          subject: "Email subject",
          message: "Email question"
        }
      }

      # Verify email job is enqueued with correct mailer, method, and kwargs.
      # This also tests that User objects serialize correctly via GlobalID.
      assert_enqueued_with(
        job: ActionMailer::MailDeliveryJob,
        args: ["UserQuestionMailer", "build", "deliver_now",
               { args: [{ sender: rolf, receiver: mary,
                          subject: "Email subject",
                          message: "Email question" }] }]
      ) do
        post_requires_login(:create, params)
      end

      assert_redirected_to(user_path(mary.id))
      assert_flash_text(:runtime_ask_user_question_success.t)
    end

    def test_send_user_question_missing_subject
      login("rolf")
      params = {
        id: mary.id,
        user_question: {
          subject: "",
          message: "Email question"
        }
      }
      post(:create, params: params)
      assert_redirected_to(user_path(mary.id))
      assert_flash_text(:runtime_ask_user_question_missing_fields.t)
    end

    def test_send_user_question_missing_message
      login("rolf")
      params = {
        id: mary.id,
        user_question: {
          subject: "Email subject",
          message: ""
        }
      }
      post(:create, params: params)
      assert_redirected_to(user_path(mary.id))
      assert_flash_text(:runtime_ask_user_question_missing_fields.t)
    end

    def test_new_turbo_stream
      login("rolf")
      get(:new, params: { id: mary.id }, as: :turbo_stream)
      assert_response(:success)
    end

    def test_create_turbo_stream
      login("rolf")
      params = {
        id: mary.id,
        user_question: {
          subject: "Email subject",
          message: "Email question"
        }
      }
      assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
        post(:create, params: params, as: :turbo_stream)
      end
      assert_response(:success)
    end
  end
end
