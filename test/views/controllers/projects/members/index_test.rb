# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Projects::Members
  class IndexTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
    end

    def test_renders_add_widget_and_table
      project = projects(:eol_project)
      users = project.user_group.users.to_a

      html = render(Index.new(project: project, users: users, user: @user))

      assert_html(html, "#project_members_widget")
      assert_html(html, "#project_members_table")
    end
  end
end
