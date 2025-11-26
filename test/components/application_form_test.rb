# frozen_string_literal: true

require "test_helper"

class ApplicationFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    @user = users(:rolf)
    @collection_number = collection_numbers(:coprinus_comatus_coll_num)

    # Set up controller request context for form URL generation
    controller.request = ActionDispatch::TestRequest.create
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
