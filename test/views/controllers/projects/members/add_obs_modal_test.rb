# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Projects::Members
  class AddObsModalTest < ComponentTestCase
    def setup
      super
      @project = projects(:eol_project)
      @candidate = users(:rolf)
    end

    def test_renders_modal_with_body_and_footer
      html = render_modal

      assert_html(html, "#modal_add_obs")
      assert_html(html, ".modal-body")
      assert_html(html, ".modal-footer")
    end

    def test_renders_cancel_button
      html = render_modal

      assert_html(html, ".modal-footer button[type='button']" \
                        "[data-dismiss='modal']",
                  text: :cancel.ti)
    end

    # Submit button uses `btn: "btn btn-primary"` (not `class:`). Verify it
    # renders with the primary style and no btn-default stacking.
    def test_submit_button_uses_primary_style_without_stacking_default
      html = render_modal(count: 3)

      assert_html(html, ".modal-footer button.btn.btn-primary")
      assert_no_html(html, "form[data-turbo='true'] button.btn-default")
    end

    def test_no_submit_button_when_count_is_zero
      html = render_modal(count: 0)

      assert_no_html(html, "form[method]")
    end

    def test_submit_button_targets_project_member_path
      html = render_modal(count: 1)

      expected_path = routes.project_member_path(
        project_id: @project.id,
        candidate: @candidate.id,
        commit: :change_member_add_obs.l,
        target: :project_index
      )
      assert_html(html, "form[action='#{expected_path}']")
    end

    def test_raises_when_raw_btn_class_passed
      assert_raises(ArgumentError) do
        Components::Button::CRUDBase.new(
          name: :add_obs_modal_add_all.l,
          target: "/ignored",
          method: :put,
          class: "btn btn-primary"
        )
      end
    end

    private

    def render_modal(project: @project, candidate: @candidate,
                     count: 5, batch_limit: 100)
      render(AddObsModal.new(
               project: project,
               candidate: candidate,
               count: count,
               batch_limit: batch_limit
             ))
    end
  end
end
