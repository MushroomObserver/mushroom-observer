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
    @html = render_form_with_reasons
  end

  def test_renders_checkbox_for_each_reason
    @naming.init_reasons.each_key do |num|
      selector = "input[type='checkbox'][name='naming[reasons][#{num}][check]']"
      assert_html(@html, selector)
    end
  end

  def test_renders_textarea_for_each_reason
    @naming.init_reasons.each_key do |num|
      assert_html(@html, "textarea[name='naming[reasons][#{num}][notes]']")
    end
  end

  def test_textarea_has_collapse_class
    assert_html(@html, "div.collapse textarea")
  end

  def test_checkbox_has_data_toggle_attribute
    assert_html(@html, "label[data-toggle='collapse']")
  end

  def test_checkbox_targets_corresponding_textarea
    @naming.init_reasons.each_key do |num|
      assert_html(@html, "label[data-target='#reasons_#{num}_notes']")
    end
  end

  def test_textarea_container_has_matching_id
    @naming.init_reasons.each_key do |num|
      assert_html(@html, "div[id='reasons_#{num}_notes']")
    end
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
    assert_html(html, "div#reasons_1_notes.collapse.in")
  end

  def test_unchecked_reason_has_collapsed_textarea
    # Container should have "collapse" but NOT "in" class (collapsed)
    assert_html(@html, "div#reasons_1_notes.collapse:not(.in)")
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
