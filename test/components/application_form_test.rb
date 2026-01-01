# frozen_string_literal: true

require "test_helper"

class ApplicationFormTest < ComponentTestCase

  def setup
    @user = users(:rolf)
    @collection_number = collection_numbers(:coprinus_comatus_coll_num)

    # Set up controller request context for form URL generation
  end

  # Text field tests
  def test_text_field_renders_with_basic_options
    form = render_form do
      text_field(:name, label: "Collection Name")
    end

    assert_includes(form, "form-group")
    assert_includes(form, "Collection Name")
    assert_includes(form, "form-control")
    assert_includes(form, 'type="text"')
  end

  def test_text_field_with_inline_option
    form = render_form do
      text_field(:name, label: "Name", inline: true)
    end

    assert_includes(form, "form-inline")
  end

  def test_text_field_with_append
    form = render_form do
      text_field(:number, label: "Number") do |f|
        f.with_append do
          p(class: "help-block") { "Help text" }
        end
      end
    end

    assert_includes(form, '<p class="help-block">Help text</p>')
  end

  def test_text_field_with_button
    form = render_form do
      text_field(:name, label: "Search", button: "Go")
    end

    assert_includes(form, "input-group")
    assert_includes(form, "input-group-btn")
    assert_includes(form, "Go")
  end

  # Textarea field tests
  def test_textarea_field_renders_with_basic_options
    form = render_form do
      textarea_field(:notes, label: "Notes")
    end

    assert_includes(form, "form-group")
    assert_includes(form, "Notes")
    assert_includes(form, "form-control")
    assert_includes(form, "<textarea")
  end

  def test_textarea_field_with_monospace
    form = render_form do
      textarea_field(:notes, label: "Notes", monospace: true)
    end

    assert_includes(form, "text-monospace")
  end

  def test_textarea_field_with_rows
    form = render_form do
      textarea_field(:notes, label: "Notes", rows: 10)
    end

    assert_includes(form, 'rows="10"')
  end

  # Checkbox field tests - CollectionNumber doesn't have boolean fields,
  # so we'll just test the rendering with a placeholder field
  def test_checkbox_field_renders_with_basic_options
    form = render_form do
      checkbox_field(:placeholder, label: "Test checkbox")
    end

    assert_includes(form, "checkbox")
    assert_includes(form, "Test checkbox")
    assert_includes(form, 'type="checkbox"')
  end

  def test_checkbox_field_applies_wrap_class_to_wrapper
    form = render_form do
      checkbox_field(:placeholder, label: "Test", wrap_class: "mt-3")
    end

    # wrap_class should be on wrapper div, not the input
    assert_match(/<div class="checkbox mt-3">/, form)
  end

  # Select field tests
  def test_select_field_renders_with_basic_options
    options = [["Option 1", "1"], ["Option 2", "2"], ["Option 3", "3"]]
    form = render_form do
      select_field(:number, options, label: "Choose")
    end

    assert_includes(form, "form-group")
    assert_includes(form, "Choose")
    assert_includes(form, "form-control")
    assert_includes(form, "<select")
    assert_includes(form, "Option 1")
    assert_includes(form, "Option 2")
    assert_includes(form, "Option 3")
  end

  # Slot tests
  def test_text_field_with_between_slot
    form = render_form do
      text_field(:name, label: "Name") do |field|
        field.with_between do
          span(class: "help-note") { "(optional)" }
        end
      end
    end

    assert_includes(form, "(optional)")
    assert_includes(form, "help-note")
  end

  def test_text_field_with_append_slot
    form = render_form do
      text_field(:name, label: "Name") do |field|
        field.with_append do
          span(class: "help-note") { "(required)" }
        end
      end
    end

    assert_includes(form, "(required)")
    assert_includes(form, "help-note")
  end

  def test_checkbox_field_with_between_slot
    form = render_form do
      checkbox_field(:placeholder, label: "Test") do |field|
        field.with_between do
          em { "Note" }
        end
      end
    end

    assert_includes(form, "<em>Note</em>")
  end

  # Custom class name test
  def test_text_field_with_custom_class_name
    form = render_form do
      text_field(:name, label: "Name", class_name: "custom-wrapper")
    end

    assert_includes(form, "custom-wrapper")
  end

  # Password field tests
  def test_password_field_renders_with_basic_options
    form = render_form do
      password_field(:password, label: "Password")
    end

    assert_includes(form, "form-group")
    assert_includes(form, "Password")
    assert_includes(form, "form-control")
    assert_includes(form, 'type="password"')
  end

  # Hidden field tests
  def test_hidden_field_renders_without_wrapper
    form = render_form do
      hidden_field(:secret, value: "hidden_value")
    end

    assert_includes(form, 'type="hidden"')
    assert_includes(form, 'value="hidden_value"')
    assert_not_includes(form, "form-group")
  end

  # Number field tests
  def test_number_field_renders_with_basic_options
    form = render_form do
      number_field(:count, label: "Count")
    end

    assert_includes(form, "form-group")
    assert_includes(form, "Count")
    assert_includes(form, "form-control")
    assert_includes(form, 'type="number"')
  end

  # Test select with custom options block - renders component directly
  def test_select_field_with_custom_options_block
    # Create a field for testing
    form = Components::ApplicationForm.new(@collection_number,
                                           action: "/test_form_path")
    select_field = form.field(:number)
    select_component = select_field.select([])

    # Render with custom options block using view_context helpers
    html = render(select_component) do
      view_context.tag.option("Option A", value: "a") +
        view_context.tag.option("Option B", value: "b")
    end

    assert_includes(html, "<select")
    assert_includes(html, "Option A")
    assert_includes(html, "Option B")
    assert_includes(html, 'value="a"')
    assert_includes(html, 'value="b"')
  end

  # Test field with inferred label (humanized field name)
  def test_text_field_with_inferred_label
    form = render_form do
      text_field(:collection_name)
    end

    # Field name :collection_name should be humanized to "Collection name"
    assert_includes(form, "Collection name")
  end

  # Test select field with inferred label (no label option, uses humanize)
  # Covers SelectField line 62: field.key.to_s.humanize
  def test_select_field_with_inferred_label
    options = [["Opt 1", "1"], ["Opt 2", "2"]]
    form = render_form do
      select_field(:collection_name, options)
    end

    # Field name :collection_name should be humanized to "Collection name"
    assert_includes(form, "Collection name")
    assert_includes(form, "<select")
  end

  # Test select with label: true (explicit non-string, non-false label)
  # Also covers SelectField line 62
  def test_select_field_with_label_true
    options = [["Opt A", "a"], ["Opt B", "b"]]
    form = render_form do
      select_field(:number, options, label: true)
    end

    # Should use humanized field name as label
    assert_includes(form, "Number")
    assert_includes(form, "<select")
  end

  # Test that link_to is available in ApplicationForm
  # This verifies Phlex::Rails::Helpers::LinkTo works via inheritance
  def test_link_to_helper_is_available
    form = render_form do
      link_to("Test Link", "/test/path", class: "test-class")
    end

    assert_includes(form, "<a")
    assert_includes(form, 'href="/test/path"')
    assert_includes(form, "Test Link")
    assert_includes(form, 'class="test-class"')
  end

  # Test that class_names is available in ApplicationForm
  # This verifies Phlex::Rails::Helpers::ClassNames works via inheritance
  def test_class_names_helper_is_available
    form = render_form do
      div(class: class_names("base-class", active: true,
                                           disabled: false)) do
        plain("Content")
      end
    end

    assert_includes(form, 'class="base-class active"')
    assert_not_includes(form, "disabled")
  end

  private

  def render_form(&block)
    # Create a test form class that extends ApplicationForm
    form_class = Class.new(Components::ApplicationForm) do
      attr_accessor :field_block

      def view_template
        # Call the block which will invoke field methods
        instance_eval(&field_block) if field_block
      end
    end

    # Create form instance with explicit action URL
    form = form_class.new(@collection_number, action: "/test_form_path")
    form.field_block = block

    render(form)
  end
end
