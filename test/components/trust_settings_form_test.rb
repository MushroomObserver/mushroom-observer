# frozen_string_literal: true

require("test_helper")

# Tests for Components::TrustSettingsForm (issue #4148).
# The form's modal chrome is provided by Components::ModalTurboForm
# at render time; these tests cover the form contents only.
class TrustSettingsFormTest < ComponentTestCase
  def test_renders_form_with_method_and_csrf_and_action
    project = projects(:eol_project)
    candidate = users(:rolf)
    html = render_form(project: project, candidate: candidate)

    expected_action = "/projects/#{project.id}/members/#{candidate.id}"
    assert_html(html, "form[action='#{expected_action}']")
    # Superform: persisted model → PATCH via _method hidden field.
    assert_html(html, "input[type='hidden'][name='_method'][value='patch']")
    assert_html(html, "input[type='hidden'][name='authenticity_token']")
    # Hidden target tells the controller where to send the user back.
    assert_html(html, "input[type='hidden'][name='target']" \
                      "[value='project_index']")
  end

  def test_renders_three_radio_options_with_commit_name_and_values
    html = render_form

    # All three radios share name="commit" — the controller switches on
    # `params[:commit]` to determine which trust level to apply.
    Components::TrustSettingsForm::OPTIONS.each do |option|
      value = option[:commit_key].l
      assert_html(html, "input[type='radio'][name='commit']" \
                        "[value='#{value}']")
    end
  end

  def test_preselects_radio_for_each_trust_level
    {
      "no_trust" => :change_member_status_revoke_trust,
      "hidden_gps" => :change_member_hidden_gps_trust,
      "editing" => :change_member_editing_trust
    }.each do |level, commit_key|
      html = render_form(current_trust_level: level)
      checked_value = commit_key.l

      assert_html(html, "input[type='radio'][name='commit']" \
                        "[value='#{checked_value}'][checked]")
      # Other two radios should not be checked
      Components::TrustSettingsForm::OPTIONS.each do |option|
        next if option[:commit_key] == commit_key

        other_value = option[:commit_key].l
        assert_no_html(html, "input[type='radio'][name='commit']" \
                             "[value='#{other_value}'][checked]")
      end
    end
  end

  def test_renders_help_text_for_each_option
    html = render_form

    assert_includes(html, :trust_settings_no_trust_help.l)
    assert_includes(html, :trust_settings_hidden_gps_help.l)
    assert_includes(html, :trust_settings_editing_help.l)
  end

  def test_renders_save_button_with_save_name_to_avoid_commit_collision
    html = render_form

    # `name="save"` avoids colliding with the radio group's `commit`
    # name (Superform's default submit name would be `commit`).
    assert_html(html, "button[type='submit'][name='save']")
    assert_includes(html, :trust_settings_save.l)
  end

  def test_renders_cancel_button_that_dismisses_modal
    html = render_form

    assert_html(html, "button[type='button'][data-dismiss='modal']")
  end

  private

  def render_form(project: projects(:eol_project),
                  candidate: users(:rolf),
                  current_trust_level: "hidden_gps")
    render(Components::TrustSettingsForm.new(
             candidate,
             project: project,
             current_trust_level: current_trust_level
           ))
  end
end
