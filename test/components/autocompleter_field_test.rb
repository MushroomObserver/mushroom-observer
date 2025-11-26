# frozen_string_literal: true

require "test_helper"

class AutocompleterFieldTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @herbarium_record = HerbariumRecord.new
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_component_has_correct_html_structure
    html = render_with_component

    # Should have outer autocompleter wrapper with type-specific controller
    # herbarium type uses autocompleter--herbarium controller
    assert_html(html, ".autocompleter[data-controller='autocompleter--herbarium']")
    assert_html(html, ".autocompleter[data-type='herbarium']")

    # Should have form-group wrapper inside with target and dropdown class
    # Namespaced targets use double-dash: data-autocompleter--herbarium-target
    wrap_target = "data-autocompleter--herbarium-target='wrap'"
    selector = ".autocompleter .form-group.dropdown[#{wrap_target}]"
    assert_html(html, selector)

    # Should have label inside form-group
    assert_nested(
      html,
      parent_selector: ".form-group.dropdown[#{wrap_target}]",
      child_selector: "label[for='herbarium_record_herbarium_name']"
    )

    # Should have input with autocompleter target inside form-group
    assert_nested(
      html,
      parent_selector: ".form-group.dropdown[#{wrap_target}]",
      child_selector: "input.form-control" \
                      "[data-autocompleter--herbarium-target='input']"
    )

    # Should have proper placeholder and autocomplete attributes
    assert_html(html, "input[placeholder='#{:start_typing.l}']")
    assert_html(html, "input[autocomplete='off']")

    # Should have dropdown menu INSIDE form-group wrapper
    wrap_selector = ".form-group.dropdown[#{wrap_target}]"
    assert_nested(
      html,
      parent_selector: wrap_selector,
      child_selector: ".auto_complete.dropdown-menu" \
                      "[data-autocompleter--herbarium-target='pulldown']"
    )

    # Should have hidden field INSIDE form-group wrapper
    assert_nested(
      html,
      parent_selector: wrap_selector,
      child_selector: "input[type='hidden']" \
                      "[name='herbarium_record[herbarium_id]']"
    )
    assert_nested(
      html,
      parent_selector: wrap_selector,
      child_selector: "input[type='hidden']" \
                      "[data-autocompleter--herbarium-target='hidden']"
    )

    # Should have virtual list inside dropdown
    assert_nested(
      html,
      parent_selector: ".auto_complete.dropdown-menu",
      child_selector: "ul.virtual_list" \
                      "[data-autocompleter--herbarium-target='list']"
    )

    # Should have 10 dropdown items with links
    assert_html(html, "li.dropdown-item", count: 10)
    assert_html(html, "li.dropdown-item a", count: 10)

    # Should have has_id_indicator (green check icon)
    assert_html(
      html,
      "span.has-id-indicator" \
      "[data-autocompleter--herbarium-target='hasIdIndicator']"
    )
    assert_html(html, "span.has-id-indicator.text-success")
  end

  def test_component_textarea_mode
    html = render_textarea_autocompleter

    # Should have textarea instead of text input
    # location type uses autocompleter--location controller
    selector = "textarea.form-control" \
               "[data-autocompleter--location-target='input']"
    assert_html(html, selector)

    # Should have textarea with correct name
    assert_html(html, "textarea[name='comment[notes]']")

    # Should still have hidden field with namespaced target
    assert_html(html,
                "input[type='hidden']" \
                "[data-autocompleter--location-target='hidden']")

    # Should still have dropdown structure
    assert_html(html, ".auto_complete.dropdown-menu")
    assert_html(html, "ul.virtual_list")
  end

  def test_hidden_field_derives_id_field_name
    html = render_with_component

    # Hidden field should transform herbarium_name to herbarium_id
    assert_html(
      html,
      "input[type='hidden'][name='herbarium_record[herbarium_id]']"
    )
  end

  def test_component_has_stimulus_data_attributes
    html = render_with_component

    # Should have all necessary Stimulus targets (namespaced for herbarium type)
    assert_html(html, "[data-autocompleter--herbarium-target='wrap']")
    assert_html(html, "[data-autocompleter--herbarium-target='input']")
    assert_html(html, "[data-autocompleter--herbarium-target='hidden']")
    assert_html(html, "[data-autocompleter--herbarium-target='pulldown']")
    assert_html(html, "[data-autocompleter--herbarium-target='list']")

    # Should have scroll action with namespaced controller
    assert_html(
      html,
      "[data-action='scroll->autocompleter--herbarium#scrollList:passive']"
    )

    # Dropdown items should have click action with namespaced controller
    doc = Nokogiri::HTML(html)
    links = doc.css("li.dropdown-item a[data-action]")
    assert(links.size == 10, "Should have 10 links with click actions")
    links.each do |link|
      action = link["data-action"]
      assert_includes(
        action,
        "click->autocompleter--herbarium#selectRow:prevent",
        "Link should have selectRow action"
      )
    end
  end

  private

  def render_with_component
    form = Components::HerbariumRecordForm.new(
      @herbarium_record,
      observation: observations(:coprinus_comatus_obs),
      herbarium_names: ["Test Herbarium"],
      action: "/test_action"
    )
    render(form)
  end

  def render_textarea_autocompleter
    # Create a simple form to test textarea mode using Comment model
    comment = Comment.new
    form = TestTextareaAutocompleterForm.new(
      comment,
      action: "/test"
    )
    render(form)
  end
end

# Test form class to demonstrate textarea autocompleter
class TestTextareaAutocompleterForm < Components::ApplicationForm
  def view_template
    super do
      render(
        field(:notes).autocompleter(
          type: :location,
          textarea: true,
          wrapper_options: { label: "Notes" }
        )
      )
    end
  end
end
