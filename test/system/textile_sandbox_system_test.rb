# frozen_string_literal: true

require("application_system_test_case")

# InfoController#textile_sandbox_create always re-renders the same
# live-preview page and never redirects, and its GET/POST URLs differ
# (/info/textile_sandbox/new vs /info/textile_sandbox) -- forces
# :unprocessable_content purely so Turbo Drive treats the response as
# an in-place redisplay instead of erroring on "Form responses must
# redirect to another location". This confirms the redisplay actually
# reaches the browser via a real Turbo submission.
class TextileSandboxSystemTest < ApplicationSystemTestCase
  def test_textile_sandbox_preview_updates_via_turbo
    login!(users(:rolf))

    visit(new_info_textile_sandbox_path)
    assert_selector("#info_textile_sandbox_form")

    fill_in("textile_sandbox_code", with: "_aborts_")
    click_button(:sandbox_test.l)

    assert_selector(".sandbox i", text: "aborts")
  end
end
