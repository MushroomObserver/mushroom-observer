# frozen_string_literal: true

require("test_helper")

module Images
  class EmailsControllerTest < FunctionalTestCase
    include ActiveJob::TestHelper

    def test_try_commercial_inquiry
      id = images(:in_situ_image).id
      requires_login(:new, id: id)
      assert_form_action(action: :create, id: id)

      # # Prove that it won't email someone who has opted out of all emails.
      mary.update(no_emails: true)
      requires_login(:new, id: id)
      assert_flash_text(:permission_denied.t)
    end

    def test_send_commercial_inquiry
      image = images(:commercial_inquiry_image)
      params = {
        id: image.id,
        commercial_inquiry: {
          content: "Testing commercial_inquiry"
        }
      }
      login("rolf")
      assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
        post(:create, params: params)
      end
      assert_redirected_to(image_path(image.id))
    end

    def test_send_commercial_inquiry_requires_content
      image = images(:commercial_inquiry_image)
      login("rolf")

      assert_no_enqueued_jobs do
        post(:create,
             params: { id: image.id, commercial_inquiry: { content: "" } })
      end
      assert_flash_error
      assert_template(:new)
    end

    def test_new_turbo_stream
      image = images(:in_situ_image)
      login("rolf")

      get(:new, params: { id: image.id }, as: :turbo_stream)

      assert_response(:success)
    end

    def test_create_turbo_stream
      image = images(:commercial_inquiry_image)
      params = {
        id: image.id,
        commercial_inquiry: { content: "Testing commercial_inquiry" }
      }
      login("rolf")

      assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
        post(:create, params: params, as: :turbo_stream)
      end
      assert_response(:success)
    end
  end
end
