# frozen_string_literal: true

require("test_helper")

module Views::Controllers::FieldSlips
  # Tests for FieldSlipPanel — the per-slip details block rendered on both
  # the show page and the index's per-row ObjectRow. Focus: the branch
  # where `@field_slip.project` is nil, which emits `:field_slip_no_project.t`
  # instead of a project link.
  class FieldSlipPanelTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      controller.instance_variable_set(:@user, @user)
    end

    def test_renders_no_project_text_when_project_is_nil
      fs = field_slips(:field_slip_project_orphan)
      html = render(FieldSlipPanel.new(field_slip: fs))

      assert_html(html, "div#field_slip_#{fs.id}")
      # PROJECT label always renders
      assert_html(html, "strong", text: "#{:project.ti}:")
      # No-project fallback text appears when project is nil
      assert_html(html, "div#field_slip_#{fs.id}",
                  text: :field_slip_no_project.t.as_displayed)
    end
  end
end
