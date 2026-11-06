# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Projects::Members
  class TablesTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
    end

    # Was Project#member_status, tested in project_test.rb -- moved
    # here (#4901) since the model method's only caller was this
    # view's table column.
    def test_member_status
      project = projects(:eol_project)
      view = Tables.new(project: project, users: [], user: @user)

      assert_equal(:owner.ti, view.send(:member_status, project.user))
      admin = (project.admin_group.users - [project.user]).first
      assert_equal(:admin.ti, view.send(:member_status, admin))
      member = (project.user_group.users - project.admin_group.users).first
      assert_equal(:member.ti, view.send(:member_status, member))
      assert_nil(view.send(:member_status, users(:zero_user)))
    end

    def test_renders_table_with_stable_wrapper_id
      project = projects(:eol_project)
      users = project.user_group.users.to_a

      html = render(Tables.new(project: project, users: users, user: @user))

      assert_html(html, "#project_members_table table.table-project-members")
    end
  end
end
