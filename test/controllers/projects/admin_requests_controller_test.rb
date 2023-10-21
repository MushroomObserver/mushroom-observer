# frozen_string_literal: true

require("test_helper")

module Projects
  class AdminRequestsControllerTest < FunctionalTestCase
    def test_post_admin_request
      eol_project = projects(:eol_project)
      params = {
        project_id: eol_project.id,
        email: {
          subject: "Admin request subject",
          content: "Message for admins"
        }
      }
      post_requires_login(:create, params)
      assert_redirected_to(project_path(eol_project.id))
      assert_flash_text(:admin_request_success.t(title: eol_project.title))
    end

    def test_admin_request
      id = projects(:eol_project).id
      requires_login(:new, project_id: id)
      assert_form_action(action: :create, project_id: id)
    end
  end
end
