# frozen_string_literal: true

require("test_helper")

module Descriptions
  # test of actions to request being a author of a description
  class AuthorRequestsControllerTest < FunctionalTestCase
    include ActiveJob::TestHelper

    def test_new
      id = name_descriptions(:coprinus_comatus_desc).id
      requires_login(:new, id: id, type: :name_description)
      assert_form_action(action: :create, id: id,
                         type: :name_description)

      id = location_descriptions(:albion_desc).id
      requires_login(:new, id: id, type: :location_description)
      assert_form_action(action: :create, id: id,
                         type: :location_description)
    end

    def test_create_name_description
      desc = name_descriptions(:coprinus_comatus_desc)
      params = {
        id: desc.id,
        type: :name_description,
        email: {
          subject: "Author request subject",
          message: "Message for authors"
        }
      }
      login
      assert_enqueued_with(
        job: ActionMailer::MailDeliveryJob,
        args: ->(args) { args[0] == "AuthorMailer" && args[1] == "build" }
      ) do
        post(:create, params: params)
      end
      assert_redirected_to(name_description_path(desc.id))
      assert_flash_text(:request_success.t)
    end

    def test_create_location_description
      desc = location_descriptions(:albion_desc)
      params = {
        id: desc.id,
        type: :location_description,
        email: {
          subject: "Author request subject",
          message: "Message for authors"
        }
      }
      login
      assert_enqueued_with(
        job: ActionMailer::MailDeliveryJob,
        args: ->(args) { args[0] == "AuthorMailer" && args[1] == "build" }
      ) do
        post(:create, params: params)
      end
      assert_redirected_to(location_description_path(desc.id))
      assert_flash_text(:request_success.t)
    end
  end
end
