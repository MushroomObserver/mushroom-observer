# frozen_string_literal: true

require("test_helper")

module Users
  class EmailsControllerTest < FunctionalTestCase
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
        email: {
          subject: "Email subject",
          content: "Email question"
        }
      }
      post_requires_login(:create, params)
      assert_redirected_to(user_path(mary.id))
      assert_flash_text(:runtime_ask_user_question_success.t)
    end
  end
end
