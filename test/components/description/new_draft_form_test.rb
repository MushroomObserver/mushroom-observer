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

  # The hidden field has to be the bare top-level "project" param
  # (not namespaced, not "project_id") to match
  # Locations::DescriptionsController#new /
  # Names::DescriptionsController#new's existing params[:project] read.
  def test_hidden_field_is_bare_project_param
    html = render_form(target: locations(:albion))

    assert_html(html, "input[type='hidden'][name='project']")
  end

  def test_prefills_from_project_prop
    project = projects(:eol_project)

    html = render_form(target: locations(:albion), project: project)

    assert_html(html, "input[name='project'][value='#{project.id}']")
    assert_html(html, "input[name='project_display'][value=" \
                      "'#{project.title}']")
  end

  def test_blank_when_no_incoming_project
    html = render_form(target: locations(:albion))

    assert_html(html, "input[name='project']:not([value])")
  end

  private

  def render_form(target:, project: nil)
    render(Components::Description::NewDraftForm.new(
             target: target, project: project
           ))
  end
end
