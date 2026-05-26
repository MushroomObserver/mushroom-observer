# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Projects::Members
  class GroupsTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
    end

    def test_renders_member_and_admin_groups
      User.current = @user
      project = projects(:eol_project)
      html = render(Views::Controllers::Projects::Members::Groups.new(
                      project: project, user: @user
                    ))

      # Member heading
      assert_includes(html, :change_member_status_members.t)
      # Admin heading
      assert_includes(html, :change_member_status_admins.t)
    end

    def test_admin_sees_edit_links
      User.current = @user
      project = projects(:eol_project)
      # rolf is the project owner/admin
      html = render(Views::Controllers::Projects::Members::Groups.new(
                      project: project, user: project.user
                    ))

      assert_includes(html, :change_member_status_change_status.t)
      assert_html(html,
                  "a[href*='edit'][href*='project']")
    end
  end
end
