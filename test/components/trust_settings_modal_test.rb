# frozen_string_literal: true

require "test_helper"

# Tests for the TrustSettingsModal component (issue #4148).
class TrustSettingsModalTest < ComponentTestCase
  def test_renders_modal_structure
    html = render_modal

    assert_html(html, "div##{Components::TrustSettingsModal::MODAL_ID}.modal")
    assert_html(html, "div.modal-dialog")
    assert_html(html, "div.modal-content")
    assert_html(html, "form[method='post']")
    assert_html(html, "input[type='hidden'][name='_method'][value='put']")
    assert_html(html, "input[type='hidden'][name='target']" \
                      "[value='project_index']")
  end

  def test_form_action_targets_member_path
    project = projects(:eol_project)
    candidate = users(:rolf)
    html = render_modal(project: project, candidate: candidate)
    expected = "/projects/#{project.id}/members/#{candidate.id}"

    assert_html(html, "form[action='#{expected}']")
  end

  def test_renders_three_radio_options
    html = render_modal

    assert_html(html, "input[type='radio'][name='commit']" \
                      "[id='trust_level_no_trust']")
    assert_html(html, "input[type='radio'][name='commit']" \
                      "[id='trust_level_hidden_gps']")
    assert_html(html, "input[type='radio'][name='commit']" \
                      "[id='trust_level_editing']")
  end

  def test_radio_values_match_existing_commit_strings
    html = render_modal

    assert_html(html, "input[type='radio']" \
                      "[value='#{:change_member_status_revoke_trust.l}']")
    assert_html(html, "input[type='radio']" \
                      "[value='#{:change_member_hidden_gps_trust.l}']")
    assert_html(html, "input[type='radio']" \
                      "[value='#{:change_member_editing_trust.l}']")
  end

  def test_preselects_current_trust_level_no_trust
    html = render_modal(current_trust_level: "no_trust")

    assert_html(html, "input#trust_level_no_trust[checked='checked']")
    assert_no_html(html, "input#trust_level_hidden_gps[checked]")
    assert_no_html(html, "input#trust_level_editing[checked]")
  end

  def test_preselects_current_trust_level_hidden_gps
    html = render_modal(current_trust_level: "hidden_gps")

    assert_html(html, "input#trust_level_hidden_gps[checked='checked']")
    assert_no_html(html, "input#trust_level_no_trust[checked]")
    assert_no_html(html, "input#trust_level_editing[checked]")
  end

  def test_preselects_current_trust_level_editing
    html = render_modal(current_trust_level: "editing")

    assert_html(html, "input#trust_level_editing[checked='checked']")
    assert_no_html(html, "input#trust_level_no_trust[checked]")
    assert_no_html(html, "input#trust_level_hidden_gps[checked]")
  end

  def test_renders_help_text_for_each_option
    html = render_modal

    assert_includes(html, :trust_settings_no_trust_help.l)
    assert_includes(html, :trust_settings_hidden_gps_help.l)
    assert_includes(html, :trust_settings_editing_help.l)
  end

  def test_renders_save_button
    html = render_modal

    assert_html(html, "button[type='submit'][name='save']")
    assert_includes(html, :trust_settings_save.l)
  end

  private

  def render_modal(project: projects(:eol_project),
                   candidate: users(:rolf),
                   current_trust_level: "hidden_gps")
    render(Components::TrustSettingsModal.new(
             project: project,
             candidate: candidate,
             current_trust_level: current_trust_level
           ))
  end
end
