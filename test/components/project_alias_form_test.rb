# frozen_string_literal: true

require("test_helper")

class ProjectAliasFormTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @project = projects(:eol_project)
  end

  def test_new_form
    html = render_form(model: ProjectAlias.new(project: @project))

    # Form structure
    assert_html(html, "form#project_alias_form")
    assert_html(html, "input[type='submit']")

    # Fields
    assert_html(html, "input[name='project_alias[name]']")
    assert_html(html, "input[type='hidden'][name='project_alias[project_id]']")
    assert_html(html, "select[name='project_alias[target_type]']")

    # Type-switch controller
    assert_html(html, "[data-controller='type-switch']")
    assert_html(html, "select[data-type-switch-target='select']")

    # Both autocompleter panels present
    panel = "[data-type-switch-target='panel']"
    assert_html(html, "#{panel}[data-type-switch-type='user']")
    assert_html(html, "#{panel}[data-type-switch-type='location']")

    # User panel hidden by default, location panel visible
    assert_html(html, "[data-type-switch-type='user'].d-none")
  end

  def test_edit_form_with_user_target
    project_alias = project_aliases(:one) # RS -> rolf (User)

    html = render_form(model: project_alias)

    # Form has existing values
    assert_html(html, "input[name='project_alias[name]'][value='RS']")

    # Location panel hidden when editing user target
    assert_html(html, "[data-type-switch-type='location'].d-none")
  end

  def test_edit_form_with_location_target
    project_alias = project_aliases(:two) # Walk 1 -> albion (Location)

    html = render_form(model: project_alias)

    # Form has existing values
    assert_html(html, "input[name='project_alias[name]'][value='Walk 1']")

    # User panel hidden when editing location target
    assert_html(html, "[data-type-switch-type='user'].d-none")
  end

  def test_form_with_errors
    project_alias = ProjectAlias.new(project: @project)
    project_alias.valid? # Trigger validation errors

    html = render_form(model: project_alias)

    # Error display
    assert_html(html, "#error_explanation")
    assert_includes(html, "error")
  end

  private

  def render_form(model:, local: true)
    render(Components::ProjectAliasForm.new(model, user: @user, local: local))
  end
end
