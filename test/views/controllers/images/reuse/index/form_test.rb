# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Images::Reuse
  class Index::FormTest < ComponentTestCase
    def setup
      super
      @obs = observations(:minimal_unknown_obs)
    end

    def test_renders_id_field_and_submit
      html = render_form(target: @obs)

      assert_html(html, "input[name='image_reuse[img_id]']")
      assert_html(html, "button[type='submit']",
                  text: :image_reuse_reuse.l.as_displayed)
    end

    def test_action_carries_placeholder_id_and_target_params
      html = render_form(target: @obs)

      expected = routes.reuse_image_path(
        Index::Form::PLACEHOLDER_ID,
        target_type: "Observation", target_id: @obs.id
      )
      assert_html(html, "form[action='#{expected}']")
    end

    def test_wires_id_sanitizer_stimulus_controller
      html = render_form(target: @obs)

      assert_html(html, "form[data-controller='id-sanitizer']" \
                        "[data-id-sanitizer-placeholder-value=" \
                        "'#{Index::Form::PLACEHOLDER_ID}']" \
                        "[data-action='submit->id-sanitizer#submit']")
      assert_html(html,
                  "input[data-id-sanitizer-target='input']")
    end

    private

    def render_form(target:)
      render(Index::Form.new(target: target))
    end
  end
end
