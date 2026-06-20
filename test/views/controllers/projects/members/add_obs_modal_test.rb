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
                  text: :CANCEL.l)
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

    # Parity: `btn: "btn btn-primary"` (new) produces the same button
    # class as the old `class: "btn btn-primary"` call on the base CrudButton
    # (which had no btn: default on Put).
    def test_btn_kwarg_parity_with_old_class_kwarg
      target = routes.project_member_path(
        project_id: @project.id,
        candidate: @candidate.id,
        commit: :change_member_add_obs.l,
        target: :project_index
      )
      old_html = render(
        Components::CrudButton.new(
          name: :add_obs_modal_add_all.l,
          target: target,
          method: :put,
          class: "btn btn-primary"
        )
      )
      new_html = render(
        Components::CrudButton::Put.new(
          name: :add_obs_modal_add_all.l,
          target: target,
          style: :primary
        )
      )

      assert_html_element_equivalent(
        "<div>#{old_html}</div>",
        "<div>#{new_html}</div>",
        selector: "div",
        label: "add_obs_modal_submit"
      )
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
