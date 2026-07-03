# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Export
  class StatusControlsTest < ComponentTestCase
    def setup
      super
      controller.define_singleton_method(:reviewer?) { true }
    end

    def test_no_render_for_non_reviewer
      controller.define_singleton_method(:reviewer?) { false }
      html = render(StatusControls.new(object: names(:fungi)))

      assert_equal("", html)
    end

    def test_ok_for_export_true_bolds_current_state
      name = names(:fungi)
      name.update_attribute(:ok_for_export, true)
      html = render(StatusControls.new(object: name))

      # Current state ("OK to export") is bold; the flip target
      # ("Don't export") renders as a PUT-method button with value: 0.
      assert_html(html, "b", text: :review_ok_for_export.t)
      assert_html(html, "form button[type='submit']",
                  text: :review_no_export.t)
      assert_html(html, "input[name='_method'][value='put']")
    end

    def test_ok_for_export_false_renders_flip_button
      # The current state ("OK to export") becomes the flip button and
      # the flip target ("Don't export") becomes bold.
      name = names(:fungi)
      name.update_attribute(:ok_for_export, false)
      html = render(StatusControls.new(object: name))

      assert_html(html, "form button[type='submit']",
                  text: :review_ok_for_export.t)
      assert_html(html, "b", text: :review_no_export.t)
    end

    def test_diagnostic_flag_for_image
      image = images(:in_situ_image)
      image.update_attribute(:diagnostic, true)
      html = render(StatusControls.new(object: image, flag: :diagnostic))

      assert_html(html, "b", text: :review_diagnostic.t)
      assert_html(html, "form button[type='submit']",
                  text: :review_non_diagnostic.t)
    end

    def test_wraps_in_dom_id_for_turbo_replace
      name = names(:fungi)
      html = render(StatusControls.new(object: name))
      dom_id = ActionView::RecordIdentifier.dom_id(name, :ok_for_export)

      assert_html(html, "div##{dom_id}")
    end

    def test_flip_button_opts_into_turbo
      name = names(:fungi)
      html = render(StatusControls.new(object: name))

      # `CRUDBase#button_html_options` shallow-merges the caller's
      # `data:` onto the *button's* html options, not the form's — so
      # `data-turbo` lands on the <button>, not the <form>. Confirmed
      # (or refuted) by a browser-level system test, since we can't
      # assume Turbo Drive's opt-in check reads the submitter element.
      assert_html(html, "button[data-turbo='true']")
    end
  end
end
