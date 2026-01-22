# frozen_string_literal: true

require "test_helper"

# NamingReasonsFields is tested through NamingForm since it requires a Superform
# namespace. See test/components/naming_form_test.rb for tests that cover the
# reasons fields functionality.
class NamingReasonsFieldsTest < ComponentTestCase
  def setup
    super
    @naming = Naming.new
    @observation = observations(:coprinus_comatus_obs)
  end

  def test_new_naming_renders_all_reasons_collapsed
    html = render_form_with_reasons

    # Verify each reason has checkbox, textarea, and proper structure
    @naming.init_reasons.each_key do |num|
      # Checkbox for each reason
      assert_html(
        html,
        "input[type='checkbox'][name='naming[reasons][#{num}][check]']"
      )
      # Textarea for each reason
      assert_html(html, "textarea[name='naming[reasons][#{num}][notes]']")
      # Label targets the corresponding textarea collapse
      assert_html(html, "label[data-target='#naming_reasons_#{num}_notes']")
      # Textarea container has matching ID
      assert_html(html, "div[id='naming_reasons_#{num}_notes']")
    end

    # Bootstrap collapse structure
    assert_html(html, "div.collapse textarea")
    assert_html(html, "label[data-toggle='collapse']")
    # Unchecked reason should be collapsed (has "collapse" but NOT "in")
    assert_html(html, "div#naming_reasons_1_notes.collapse:not(.in)")
  end

  def test_checked_reason_shows_expanded_textarea
    reasons = @naming.init_reasons
    reasons[1].notes = "Test notes"
    html = render_form_with_reasons(reasons: reasons)

    # Checkbox should be checked
    assert_html(
      html,
      "input[type='checkbox'][name='naming[reasons][1][check]'][checked]"
    )
    # Container should have "collapse in" classes (Bootstrap 3 expanded)
    assert_html(html, "div#naming_reasons_1_notes.collapse.in")
  end

  private

  def render_form_with_reasons(reasons: nil)
    form = Components::NamingForm.new(
      @naming,
      observation: @observation,
      reasons: reasons || @naming.init_reasons,
      show_reasons: true,
      context: "lightbox"
    )
    render(form)
  end
end
