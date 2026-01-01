# frozen_string_literal: true

require "test_helper"

class AutocompleterFieldTest < ComponentTestCase

  def setup
    super
    @herbarium_record = HerbariumRecord.new
  end

  def test_component_has_correct_html_structure
    html = render_with_component

    # Should have outer autocompleter wrapper with type-specific controller
    # herbarium type uses autocompleter--herbarium controller
    assert_html(html,
                ".autocompleter[data-controller='autocompleter--herbarium']")
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
    # Hidden field name matches field key (herbarium_name → herbarium_name_id)
    assert_nested(
      html,
      parent_selector: wrap_selector,
      child_selector: "input[type='hidden']" \
                      "[name='herbarium_record[herbarium_name_id]']"
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

  def test_textarea_autocompleter_has_newline_separator
    html = render_textarea_autocompleter

    # Textarea autocompleters should have newline separator for multi-value
    assert_html(html, ".autocompleter[data-separator='\n']")
  end

  def test_text_input_autocompleter_has_no_separator
    html = render_with_component

    # Text input autocompleters should NOT have separator (single value only)
    assert_no_html(html, ".autocompleter[data-separator]",
                   "Text input autocompleter should not have separator attribute")
  end

  def test_hidden_field_derives_id_field_name
    html = render_with_component

    # Hidden field name is field_key + _id (herbarium_name → herbarium_name_id)
    # This ensures controllers receive the expected param name
    assert_html(
      html,
      "input[type='hidden'][name='herbarium_record[herbarium_name_id]']"
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
    selector = "li.dropdown-item " \
               "a[data-action*='click->autocompleter--herbarium#selectRow']"
    assert_html(html, selector, count: 10)
  end

  def test_unknown_autocompleter_type_logs_warning
    # Test that an unknown type logs a warning (line 87)
    comment = Comment.new
    form = TestUnknownTypeAutocompleterForm.new(comment, action: "/test")

    # Capture Rails logger output
    old_logger = Rails.logger
    log_output = StringIO.new
    Rails.logger = Logger.new(log_output)

    render(form)

    Rails.logger = old_logger
    assert_includes(log_output.string,
                    "Unknown autocompleter type: unknown_type")
  end

  def test_autocompleter_with_find_text_option
    # Test find_text option renders find button (lines 174, 176)
    comment = Comment.new
    form = TestFindTextAutocompleterForm.new(comment, action: "/test")
    html = render(form)

    # Should have find button with correct attributes
    assert_html(html, "a.find-btn[name='find_location']")
    assert_html(html, "a[data-map-target='showBoxBtn']")
    assert_html(html, "a[data-action='map#showBox:prevent']")
  end

  def test_autocompleter_with_keep_text_option
    # Test keep_text option renders keep and edit buttons
    comment = Comment.new
    form = TestKeepTextAutocompleterForm.new(comment, action: "/test")
    html = render(form)

    # Should have keep button
    assert_html(html, "a.keep-btn[name='keep_location']")
    assert_html(html, "a[data-map-target='lockBoxBtn']")

    # Should have edit button
    assert_html(html, "a.edit-btn[name='edit_location']")
    assert_html(html, "a[data-map-target='editBoxBtn']")
  end

  def test_autocompleter_with_create_text_option
    comment = Comment.new
    form = TestCreateTextAutocompleterForm.new(comment, action: "/test")
    html = render(form)

    assert_html(html, "a.create-button[name='create_location']")
    assert_html(html, "a#create_location_btn")
  end

  def test_autocompleter_with_modal_create_link
    comment = Comment.new
    form = TestModalCreateAutocompleterForm.new(comment, action: "/test")
    html = render(form)

    assert_html(html, "a.create-link[name='create_location']")
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

# Test form class for unknown autocompleter type
class TestUnknownTypeAutocompleterForm < Components::ApplicationForm
  def view_template
    super do
      render(
        field(:notes).autocompleter(
          type: :unknown_type,
          wrapper_options: { label: "Notes" }
        )
      )
    end
  end
end

# Test form class for find_text option
class TestFindTextAutocompleterForm < Components::ApplicationForm
  def view_template
    super do
      render(
        field(:notes).autocompleter(
          type: :location,
          find_text: "Find on map",
          wrapper_options: { label: "Location" }
        )
      )
    end
  end
end

# Test form class for keep_text option (includes edit button)
class TestKeepTextAutocompleterForm < Components::ApplicationForm
  def view_template
    super do
      render(
        field(:notes).autocompleter(
          type: :location,
          keep_text: "Keep this area",
          edit_text: "Edit area",
          wrapper_options: { label: "Location" }
        )
      )
    end
  end
end

# Test form class for create_text option (without create param)
class TestCreateTextAutocompleterForm < Components::ApplicationForm
  def view_template
    super do
      render(
        field(:notes).autocompleter(
          type: :location,
          create_text: "Create new",
          wrapper_options: { label: "Location" }
        )
      )
    end
  end
end

# Test form class for modal create link (with create and create_path)
class TestModalCreateAutocompleterForm < Components::ApplicationForm
  def view_template
    super do
      render(
        field(:notes).autocompleter(
          type: :location,
          create_text: "Create new",
          create: "New Location",
          create_path: "/locations/new",
          wrapper_options: { label: "Location" }
        )
      )
    end
  end
end
