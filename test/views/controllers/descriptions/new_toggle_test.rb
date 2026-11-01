# frozen_string_literal: true

require "test_helper"

class Views::Controllers::Descriptions::NewToggleTest < ComponentTestCase
  def setup
    super
    @location = locations(:albion)
    # source_type: "public" mirrors initialize_description_source --
    # the controller seeds new descriptions before rendering.
    @description = LocationDescription.new(location: @location,
                                           source_type: "public")
  end

  def test_renders_toggle_for_project_member
    html = render_toggle(user: users(:rolf))

    assert_html(html, "[data-controller='collapse-switch']")
    assert_html(html, "label", text: :show_description_new_draft_toggle.t)
    assert_html(html,
                "input[type='radio'][name='is_project_draft'][value='no']")
    assert_html(html,
                "input[type='radio'][name='is_project_draft'][value='yes']")
  end

  def test_no_radio_is_checked_and_panel_expanded_by_default
    html = render_toggle(user: users(:rolf))

    assert_html(html, "input[value='no'][checked]")
    assert_html(html,
                "[data-collapse-switch-type='no'].collapse.in")
    assert_html(html, "[data-collapse-switch-type='yes'].collapse")
    assert_no_html(html, "[data-collapse-switch-type='yes'].collapse.in")
  end

  def test_radios_wired_to_collapse_switch
    html = render_toggle(user: users(:rolf))

    assert_html(html,
                "input[type='radio']" \
                "[data-action='change->collapse-switch#switch']",
                count: 2)
  end

  def test_no_panel_renders_main_form
    html = render_toggle(user: users(:rolf))

    assert_html(html, "form[id='location_description_form']")
  end

  def test_yes_panel_renders_project_autocompleter
    html = render_toggle(user: users(:rolf))

    assert_html(html, ".autocompleter")
    assert_html(html, "button[type='submit']")
  end

  def test_renders_only_main_form_when_project_chosen
    html = render_toggle(user: users(:rolf),
                         project: projects(:eol_project),
                         project_chosen: true)

    assert_no_html(html, "[data-controller='collapse-switch']")
    assert_html(html, "form[id='location_description_form']")
    assert_no_html(html, ".autocompleter")
  end

  def test_renders_only_main_form_for_user_with_no_projects
    html = render_toggle(user: users(:zero_user))

    assert_no_html(html, "[data-controller='collapse-switch']")
    assert_html(html, "form[id='location_description_form']")
    assert_no_html(html, ".autocompleter")
  end

  def test_renders_toggle_for_name_description
    name = names(:peltigera)
    description = NameDescription.new(name: name, source_type: "public")
    controller.instance_variable_set(:@user, users(:rolf))

    html = render(Views::Controllers::Descriptions::NewToggle.new(
                    target: name, description: description,
                    user: users(:rolf)
                  ))

    assert_html(html, "[data-controller='collapse-switch']")
    assert_html(html, "form[id='name_description_form']")
  end

  private

  def render_toggle(user:, project: nil, project_chosen: false)
    controller.instance_variable_set(:@user, user)
    render(Views::Controllers::Descriptions::NewToggle.new(
             target: @location, description: @description, user: user,
             project: project, project_chosen: project_chosen
           ))
  end
end
