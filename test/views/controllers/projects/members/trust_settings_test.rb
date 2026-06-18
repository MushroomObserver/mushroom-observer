# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Projects::Members
  # Tests for TrustSettings (issue #4148).
  # The form's modal chrome is provided by Components::Modal::TurboForm
  # at render time; these tests cover the form contents only — but the
  # form does emit its own `.modal-body` and `.modal-footer` divs so
  # they're testable here.
  class TrustSettingsTest < ComponentTestCase
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

    def test_form_wraps_modal_body_and_modal_footer
      # The form spans both modal sections, so the submit button (in
      # `.modal-footer`) is naturally inside the form. Locks in the
      # post-#4293 structure (Modal `:form_content` slot).
      html = render_form

      assert_html(html, "form > .modal-body")
      assert_html(html, "form > .modal-footer")
      # Body holds the radios, footer holds the buttons.
      assert_html(html, ".modal-body input[type='radio'][name='commit']",
                  count: 3)
      assert_html(html, ".modal-footer button[type='submit'][name='save']")
      assert_html(html, ".modal-footer button[data-dismiss='modal']")
    end

    def test_body_id_and_flash_id_are_applied_when_provided
      # ModalTurboForm passes these so external turbo-streams can target
      # the body and inject in-modal flash messages.
      html = render_form(modal_ids: { body: "modal_x_body",
                                      flash: "modal_x_flash" })

      assert_html(html, ".modal-body#modal_x_body > #modal_x_flash")
    end

    def test_body_id_and_flash_slot_omitted_when_not_provided
      # Standalone render (no ModalTurboForm) shouldn't synthesize ids.
      html = render_form

      assert_no_html(html, ".modal-body[id]")
      assert_html(html, ".modal-body > p", text: :trust_settings_help.l)
    end

    def test_renders_three_radio_options_with_commit_name_and_values
      html = render_form

      # All three radios share name="commit" — the controller switches on
      # `params[:commit]` to determine which trust level to apply.
      TrustSettings::OPTIONS.each do |option|
        value = option[:commit_key].l
        assert_html(html, "input[type='radio'][name='commit']" \
                          "[value='#{value}']")
      end
      # Each radio is wrapped in `.radio.mb-2` to match the pre-refactor
      # spacing — locks in `wrapper_options: { wrap_class: "mb-2" }`.
      assert_html(html, "div.radio.mb-2", count: 3)
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
        TrustSettings::OPTIONS.each do |option|
          next if option[:commit_key] == commit_key

          other_value = option[:commit_key].l
          assert_no_html(html, "input[type='radio'][name='commit']" \
                               "[value='#{other_value}'][checked]")
        end
      end
    end

    def test_renders_help_text_for_each_option
      html = render_form

      # Help text lives in `div.ml-4.text-muted` inside each radio's label.
      # There are three such divs (one per option), so check that EACH
      # expected help string appears in at least one of them.
      help_div_texts = Nokogiri::HTML(html).css("label > div.ml-4.text-muted").
                       map(&:text)
      [:trust_settings_no_trust_help,
       :trust_settings_hidden_gps_help,
       :trust_settings_editing_help].each do |help_key|
        expected = help_key.l
        assert(help_div_texts.any? { |t| t.include?(expected) },
               "No help div contains #{expected.inspect}")
      end
    end

    def test_renders_save_button_with_save_name_to_avoid_commit_collision
      html = render_form

      # `name="save"` avoids colliding with the radio group's `commit`
      # name (Superform's default submit name would be `commit`).
      assert_html(html, "button[type='submit'][name='save']",
                  text: :trust_settings_save.l)
    end

    def test_renders_cancel_button_that_dismisses_modal
      html = render_form

      assert_html(html, "button[type='button'][data-dismiss='modal']",
                  text: :CANCEL.l)
    end

    private

    def render_form(project: projects(:eol_project),
                    candidate: users(:rolf),
                    current_trust_level: "hidden_gps",
                    modal_ids: {})
      render(TrustSettings.new(
               candidate,
               project: project,
               current_trust_level: current_trust_level,
               modal_ids: modal_ids
             ))
    end
  end
end
