# frozen_string_literal: true

require_relative("legacy_helpers")

# Shared harness for the observations/show partial → Phlex parity
# tests. Each test class renders both the legacy ERB partial AND
# the new Phlex view with identical inputs, then asserts the two
# subtrees are structurally equivalent via
# `assert_html_element_equivalent` (attribute-order-agnostic,
# CSRF-normalized).
#
# Because the ERB partials and their helpers were deleted when
# the Phlex panels landed, both are preserved as test-only
# fixtures:
# - `test/views/controllers/observations/show/legacy_partials/*.erb`
# - `test/views/controllers/observations/show/legacy_helpers.rb`
#
# When this PR merges and the parity tests have served their
# purpose, both fixtures + the parity-test files can be deleted
# together — they're transient verification, not permanent
# coverage. (The panels themselves have their own component-level
# test files; the parity-test gap is closed once the panels are
# the only thing rendering this markup in production.)
module Views::Controllers::Observations::Show::ParityHelper
  def setup
    super
    @user = users(:rolf)
    @obs = observations(:detailed_unknown_obs)
    # Add the legacy-partials directory to the controller's view
    # paths so `render_legacy_erb("foo")` resolves to
    # `legacy_partials/_foo.erb`.
    controller.prepend_view_path(
      Rails.root.join("test/views/controllers/observations/show").to_s
    )
    # Mix the restored deleted helpers into the test controller so
    # the legacy ERB partials can resolve them.
    helper_mod = Views::Controllers::Observations::Show::LegacyHelpers
    controller.class.helper(helper_mod)
  end

  private

  # Render a legacy ERB partial preserved as a test fixture under
  # `legacy_partials/_<name>.erb`.
  def render_legacy_erb(name, locals = {})
    view_context.render(
      partial: "legacy_partials/#{name}", locals: locals
    )
  end
end
