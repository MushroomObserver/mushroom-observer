# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Projects::Members
  class FormTest < ComponentTestCase
    def setup
      super
      @project = projects(:eol_project)
      @user = users(:rolf)
    end

    def test_edit_form_for_existing_member
      # Mary is a member of eol_project
      mary = users(:mary)
      project_member = @project.project_members.find_by(user: mary)

      html = render_form(project_member)

      # Form structure
      assert_html(html, "form#project_member_form")
      expected_action = "/projects/#{@project.id}/members/#{mary.id}"
      assert_html(html, "form[action='#{expected_action}']")

      # Status buttons
      assert_html(html, "button[type='submit']",
                  text: :change_member_status_make_member.l)
      assert_html(html, "button[type='submit']",
                  text: :change_member_status_remove_member.l)
      assert_html(html, "button[type='submit']",
                  text: :change_member_status_make_admin.l)

      # Help text
      assert_includes(html, :change_member_status_make_member_help.t)
      assert_includes(html, :change_member_status_remove_member_help.t)
      assert_includes(html, :change_member_status_make_admin_help.t)
    end

    private

    def render_form(project_member)
      render(Form.new(project_member,
                      project: @project))
    end
  end
end
