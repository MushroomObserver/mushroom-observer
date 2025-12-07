# frozen_string_literal: true

require "test_helper"

# NamingReasonsFields is tested through NamingForm since it requires a Superform
# namespace. See test/components/naming_form_test.rb for tests that cover the
# reasons fields functionality.
class NamingReasonsFieldsTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @naming = Naming.new
    @observation = observations(:coprinus_comatus_obs)
    controller.request = ActionDispatch::TestRequest.create
    @html = render_form_with_reasons
  end

  def test_renders_checkbox_for_each_reason
    @naming.init_reasons.each_key do |num|
      assert_html(@html,
                  "input[type='checkbox'][name='naming[reasons][#{num}][check]']")
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

    doc = Nokogiri::HTML(html)
    checkbox = doc.at_css("input[type='checkbox'][name='naming[reasons][1][check]']")
    container = doc.at_css("div[id='reasons_1_notes']")

    assert(checkbox["checked"], "checkbox should be checked")
    assert_includes(container["class"], "show")
  end

  def test_unchecked_reason_has_collapsed_textarea
    doc = Nokogiri::HTML(@html)
    container = doc.at_css("div[id='reasons_1_notes']")

    refute_includes(container["class"], "show")
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
