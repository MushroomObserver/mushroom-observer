# frozen_string_literal: true

require("test_helper")

# Parity harness between `_field_slip.html.erb` and the new Phlex
# `Views::Controllers::FieldSlips::FieldSlipPanel`. The ERB partial
# is being replaced; this test renders both with identical inputs
# and asserts the rendered fragments are structurally equivalent
# (attribute order / classes / nesting). Delete after the ERB is
# removed.
module Views::Controllers::FieldSlips
  class FieldSlipPanelParityTest < ComponentTestCase
    def setup
      super
      # `ComponentTestCase`'s test controller doesn't inherit
      # `ApplicationController`'s `append_view_path` for the
      # `app/views/controllers/` root — add it ourselves so
      # `view_context.render(partial: "field_slips/field_slip")`
      # resolves to the ERB partial.
      controller.append_view_path(
        Rails.root.join("app/views/controllers")
      )
      @user = users(:rolf)
      controller.instance_variable_set(:@user, @user)
      # The ERB partial pulls `current_user` via the helper chain;
      # stub the controller-side `current_user` so the rendered
      # `Components::MatrixBox` gets the same viewer in both paths.
      viewer = @user
      controller.define_singleton_method(:current_user) { viewer }
    end

    def test_field_slip_with_observation_and_project
      slip = field_slips(:field_slip_one)
      assert_parity(slip)
    end

    def test_field_slip_without_observations
      slip = field_slips(:field_slip_no_obs)
      assert_parity(slip)
    end

    def test_field_slip_with_prepend_block
      slip = field_slips(:field_slip_one)
      prepend_html = view_context.tag.h4("hello").to_s
      assert_parity(slip, prepend: prepend_html)
    end

    private

    def assert_parity(slip, prepend: nil)
      erb_html = view_context.render(
        partial: "field_slips/field_slip",
        locals: { field_slip: slip, prepend: prepend }
      )
      phlex_html = render(
        FieldSlipPanel.new(field_slip: slip, prepend: prepend)
      )

      assert_html_element_equivalent(
        erb_html, phlex_html,
        selector: "div#field_slip_#{slip.id}",
        label: "field_slip_panel"
      )
    end
  end
end
