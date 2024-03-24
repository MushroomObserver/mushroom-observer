# frozen_string_literal: true

require("test_helper")

module Images
  class EmailsControllerTest < FunctionalTestCase
    def test_ask_questions
      id = images(:in_situ_image).id
      requires_login(:commercial_inquiry, id: id)
      assert_form_action(action: :create, id: id)

      # # Prove that trying to ask question of user who refuses questions
      # # redirects to that user's page (instead of an email form).
      # user = users(:no_general_questions_user)
      # requires_login(:new, id: user.id)
      # assert_flash_text(:permission_denied.t)

      # # Prove that it won't email someone who has opted out of all emails.
      # mary.update(no_emails: true)
      # requires_login(:new, id: mary.id)
      # assert_flash_text(:permission_denied.t)
    end

    def test_send_commercial_inquiry
      image = images(:commercial_inquiry_image)
      params = {
        id: image.id,
        commercial_inquiry: {
          content: "Testing commercial_inquiry"
        }
      }
      post_requires_login(:create, params)
      assert_redirected_to(image_path(image.id))
    end
  end
end
