# frozen_string_literal: true

require("test_helper")

class ProjectMemberFormTest < ComponentTestCase
  def setup
    super
    @project = projects(:eol_project)
    @user = users(:rolf)
  end

  def test_new_form
    project_member = ProjectMember.new(project: @project)
    html = render_form(project_member)

    # Form structure
    assert_html(html, "form#project_member_form")
    assert_html(html, "form[action='/projects/#{@project.id}/members']")
    assert_html(html, "input[type='submit'][value='#{:ADD.l}']")

    # Autocompleter field
    assert_html(html, "[data-controller*='autocompleter']")
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
    assert_html(html, "input[type='submit']" \
                      "[value='#{:change_member_status_make_member.l}']")
    assert_html(html, "input[type='submit']" \
                      "[value='#{:change_member_status_remove_member.l}']")
    assert_html(html, "input[type='submit']" \
                      "[value='#{:change_member_status_make_admin.l}']")

    # Help text
    assert_includes(html, :change_member_status_make_member_help.t)
  end

  def test_edit_form_for_non_member
    # Create a new ProjectMember for a user who isn't yet a member
    katrina = users(:katrina)
    project_member = ProjectMember.new(project: @project, user: katrina)

    html = render_form(project_member)

    # Should render create form since not persisted
    assert_html(html, "form#project_member_form")
    assert_html(html, "form[action='/projects/#{@project.id}/members']")
    assert_html(html, "[data-controller*='autocompleter']")
  end

  private

  def render_form(project_member)
    render(Components::ProjectMemberForm.new(project_member,
                                             project: @project))
  end
end
