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

    # Should have outer autocompleter wrapper with controller
    assert_html(html, ".autocompleter[data-controller='autocompleter']")
    assert_html(html, ".autocompleter[data-type='herbarium']")

    # Should have form-group wrapper inside with target
    assert_html(html,
                ".autocompleter .form-group[data-autocompleter-target='wrap']")

    # Should have label
    assert_html(html, "label[for='herbarium_record_herbarium_name']")

    # Should have input with dropdown class and autocompleter target
    assert_html(
      html,
      "input.dropdown.form-control[data-autocompleter-target='input']"
    )

    # Should have proper placeholder and autocomplete attributes
    assert_html(html, "input[placeholder='#{:start_typing.l}']")
    assert_html(html, "input[autocomplete='off']")

    # Should have hidden field for ID with correct name
    assert_html(
      html,
      "input[type='hidden'][name='herbarium_record[herbarium_id]']"
    )
    assert_html(
      html,
      "input[type='hidden'][data-autocompleter-target='hidden']"
    )

    # Should have dropdown menu
    assert_html(html, ".auto_complete.dropdown-menu")
    assert_html(
      html,
      ".auto_complete[data-autocompleter-target='pulldown']"
    )

    # Should have virtual list
    assert_html(html, "ul.virtual_list[data-autocompleter-target='list']")

    # Should have 10 dropdown items with links
    assert_html(html, "li.dropdown-item", count: 10)
    assert_html(html, "li.dropdown-item a", count: 10)
  end

  def test_component_textarea_mode
    html = render_textarea_autocompleter

    # Should have textarea instead of text input
    selector = "textarea.dropdown.form-control" \
               "[data-autocompleter-target='input']"
    assert_html(html, selector)

    # Should have textarea with correct name
    assert_html(html, "textarea[name='comment[notes]']")

    # Should still have hidden field
    assert_html(html,
                "input[type='hidden'][data-autocompleter-target='hidden']")

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

    # Should have all necessary Stimulus targets
    assert_html(html, "[data-autocompleter-target='wrap']")
    assert_html(html, "[data-autocompleter-target='input']")
    assert_html(html, "[data-autocompleter-target='hidden']")
    assert_html(html, "[data-autocompleter-target='pulldown']")
    assert_html(html, "[data-autocompleter-target='list']")

    # Should have scroll action
    assert_html(
      html,
      "[data-action='scroll->autocompleter#scrollList:passive']"
    )

    # Dropdown items should have click action
    doc = Nokogiri::HTML(html)
    links = doc.css("li.dropdown-item a[data-action]")
    assert(links.size == 10, "Should have 10 links with click actions")
    links.each do |link|
      action = link["data-action"]
      assert_includes(
        action,
        "click->autocompleter#selectRow:prevent",
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
