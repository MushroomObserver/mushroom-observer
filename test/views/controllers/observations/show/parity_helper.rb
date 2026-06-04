# frozen_string_literal: true

# Shared harness for the observations/show partial → Phlex parity
# tests. Each subclass renders both the legacy ERB partial AND the
# new Phlex view with identical inputs, then asserts the two
# subtrees are structurally equivalent via
# `assert_html_element_equivalent` (attribute-order-agnostic,
# CSRF-normalized).
#
# Used by `app/views/controllers/observations/show/*.rb` parity
# tests during the partial-conversion sweep. Once all callers point
# at the Phlex view and the ERB is deleted, the corresponding
# parity test should be deleted along with it.
module Views::Controllers::Observations::Show::ParityHelper
  def setup
    super
    @user = users(:rolf)
    @obs = observations(:detailed_unknown_obs)
    # The test controller used by ComponentTestCase doesn't inherit
    # ApplicationController's `append_view_path(app/views/controllers)`,
    # so a parity test rendering an ERB partial via `view_context.render(
    # partial: "foo/bar")` needs to add that path itself.
    controller.prepend_view_path(
      Rails.root.join("app/views/controllers").to_s
    )
  end

  private

  def render_erb_partial(name, locals)
    view_context.render(partial: "observations/show/#{name}", locals: locals)
  end
end
