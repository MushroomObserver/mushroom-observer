# frozen_string_literal: true

require "test_helper"

class Components::Description::NewDraftFormTest < ComponentTestCase
  def test_form_action_for_location
    location = locations(:albion)

    html = render_form(target: location)

    assert_html(
      html,
      "form[action='#{routes.new_location_description_path(
        location_id: location.id
      )}'][method='get']"
    )
  end

  def test_form_action_for_name
    name = names(:peltigera)

    html = render_form(target: name)

    assert_html(
      html,
      "form[action='#{routes.new_name_description_path(
        name_id: name.id
      )}'][method='get']"
    )
  end

  def test_renders_project_autocompleter_and_submit_button
    html = render_form(target: locations(:albion))

    assert_html(html, ".autocompleter")
    assert_html(html, "button[type='submit']")
  end

  def test_renders_project_label
    html = render_form(target: locations(:albion))

    assert_html(html, "label", text: :show_description_new_draft_label.t)
  end

  # Standard AutocompleterField naming: hidden field is "project_id",
  # matching what `initialize_description_source` reads as a
  # confirmed choice.
  def test_hidden_field_is_project_id
    html = render_form(target: locations(:albion))

    assert_html(html, "input[type='hidden'][name='project_id']")
  end

  # `project:` is a suggestion (e.g. derived from the ambient query
  # the caller arrived with), not a commitment -- the form still
  # renders, prefilled.
  def test_prefills_from_project_prop
    project = projects(:eol_project)

    html = render_form(target: locations(:albion), project: project)

    assert_html(html, "input[name='project_id'][value='#{project.id}']")
    assert_html(html, "input[name='project'][value='#{project.title}']")
  end

  def test_blank_when_no_incoming_project
    html = render_form(target: locations(:albion))

    assert_html(html, "input[name='project_id']:not([value])")
  end

  def test_member_sees_user_scoped_autocompleter
    html = render_form(target: locations(:albion), user: users(:rolf))

    assert_html(html, "[data-controller='autocompleter--user-project']")
  end

  # `project_chosen: true` means the main form already committed --
  # nothing left to pick, regardless of whether `project:` is also
  # set (it would be, in practice: the confirmed value).
  def test_does_not_render_when_project_chosen
    html = render_form(target: locations(:albion), user: users(:rolf),
                       project: projects(:eol_project), project_chosen: true)

    assert_equal("", html)
  end

  def test_does_not_render_for_user_with_no_projects
    html = render_form(target: locations(:albion), user: users(:zero_user))

    assert_equal("", html)
  end

  def test_renders_for_admin_with_no_projects_using_all_projects_type
    html = render_form(target: locations(:albion), user: users(:zero_user),
                       admin: true)

    assert_html(html, "[data-controller='autocompleter--project']")
  end

  private

  def render_form(target:, project: nil, project_chosen: false,
                  user: users(:rolf), admin: false)
    stub_admin_mode! if admin
    controller.instance_variable_set(:@user, user)
    render(Components::Description::NewDraftForm.new(
             target: target, project: project, project_chosen: project_chosen
           ))
  end
end
