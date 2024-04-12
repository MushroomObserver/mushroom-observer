# frozen_string_literal: true

require("test_helper")

module Descriptions
  # test of actions to request being a author of a description
  class AuthorRequestsControllerTest < FunctionalTestCase
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

    def test_create
      params = {
        id: name_descriptions(:coprinus_comatus_desc).id,
        type: :name_description,
        email: {
          subject: "Author request subject",
          message: "Message for authors"
        }
      }
      post_requires_login(:create, params)
      assert_redirected_to(name_description_path(
                             name_descriptions(:coprinus_comatus_desc).id
                           ))
      assert_flash_text(:request_success.t)

      params = {
        id: location_descriptions(:albion_desc).id,
        type: :location_description,
        email: {
          subject: "Author request subject",
          message: "Message for authors"
        }
      }
      post_requires_login(:create, params)
      assert_redirected_to(location_description_path(
                             location_descriptions(:albion_desc).id
                           ))
      assert_flash_text(:request_success.t)
    end
  end
end
