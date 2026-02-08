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

  # Date field tests
  def test_date_field_renders_structure
    form = render_form do
      date_field(:when, label: "Date")
    end

    # Wrapper and label
    assert_html(form, "div.form-group")
    assert_html(form, "label", text: "Date")
    assert_html(form, "div.date-selects")

    # Day select (3i) - rendered first
    assert_html(form, "select#collection_number_when_3i")
    assert_html(form, "select[name='collection_number[when(3i)]']")

    # Month select (2i) - rendered second
    assert_html(form, "select#collection_number_when_2i")
    assert_html(form, "select[name='collection_number[when(2i)]']")

    # Year text input (1i) - rendered last, not a select
    assert_html(form, "input[type='text']#collection_number_when_1i")
    assert_html(form, "input[name='collection_number[when(1i)]'][size='4']")

    # Verify order: day, month, year (3i before 2i before 1i)
    assert_match(/_3i.*_2i.*_1i/m, form)
  end

  def test_date_field_with_append_slot
    form = render_form do
      date_field(:when, label: "Date") do |field|
        field.with_append do
          span(class: "help-note") { "(approximate)" }
        end
      end
    end

    assert_html(form, "span.help-note", text: "(approximate)")
  end

  # File field tests
  def test_file_field_renders_with_defaults
    form = render_form do
      file_field(:image, label: "Upload Image")
    end

    # Wrapper with file-input controller
    assert_html(form, "div.form-group[data-controller='file-input']")
    assert_includes(form, "Upload Image")

    # File input with accept attribute (default: image/*)
    assert_html(form, "input[type='file']")
    assert_html(form, "input[accept='image/*']")

    # Validation data attributes
    assert_includes(form, "file-input#validate")
    assert_includes(form, "data-file-input-target")
    assert_includes(form, "data-max-upload-size")

    # Filename display span
    assert_html(form, "span[data-file-input-target='name']")
  end

  def test_file_field_with_multiple
    form = render_form do
      file_field(:images, label: "Upload Images", multiple: true)
    end

    assert_html(form, "input[type='file'][multiple]")
    assert_html(form, "input[accept='image/*']")
  end

  def test_file_field_with_custom_controller
    form = render_form do
      file_field(:images,
                 label: "Images",
                 controller: "form-images",
                 action: "change->form-images#addSelectedFiles")
    end

    # Should NOT have file-input controller on wrapper
    assert_no_match(/data-controller=['"]file-input['"]/, form)

    # Should have custom action
    assert_includes(form, "change->form-images#addSelectedFiles")

    # Should NOT render filename display (that's for file-input controller)
    assert_not_includes(form, "data-file-input-target=\"name\"")
  end

  def test_file_field_with_custom_accept
    form = render_form do
      file_field(:document, label: "Upload PDF", accept: "application/pdf")
    end

    assert_html(form, "input[accept='application/pdf']")
  end

  def test_file_field_with_custom_button_text
    form = render_form do
      file_field(:image, label: "Image", button_text: "Choose file...")
    end

    assert_includes(form, "Choose file...")
  end

  # Turbo stream form tests (local: false)
  def test_turbo_stream_form_has_data_turbo_attribute
    form = render_form(local: false) do
      text_field(:name, label: "Name")
    end

    assert_html(form, "form[data-turbo='true']")
  end

  def test_local_form_does_not_have_data_turbo_attribute
    form = render_form(local: true) do
      text_field(:name, label: "Name")
    end

    assert_no_html(form, "form[data-turbo]")
  end

  # Submit button tests
  def test_submit_with_center_option
    form = render_form do
      submit("Save", center: true)
    end

    assert_html(form, "input[type='submit'].center-block")
    assert_includes(form, "my-3")
  end

  def test_submit_with_custom_submits_with
    form = render_form do
      submit("Save", submits_with: "Saving...")
    end

    assert_html(form, "input[data-turbo-submits-with='Saving...']")
  end

  def test_submit_with_custom_data_attributes
    form = render_form do
      submit("Save", data: { confirm: "Are you sure?" })
    end

    assert_html(form, "input[data-confirm='Are you sure?']")
  end

  # Upload fields tests
  def test_upload_fields_renders_all_components
    # Create an observation for testing upload fields
    observation = observations(:minimal_unknown_obs)

    form = render_upload_form(observation) do
      upload_fields(
        copyright_holder: "Test User",
        copyright_year: 2024,
        licenses: [["Creative Commons", 1], ["Public Domain", 2]],
        upload_license_id: 1
      )
    end

    # Image file field
    assert_html(form, "input[type='file']")
    assert_includes(form, :IMAGE.l)

    # Copyright holder field
    assert_includes(form, :image_copyright_holder.l)
    assert_html(form, "input[value='Test User']")

    # Year select
    assert_includes(form, :WHEN.l)
    assert_html(form, "select")
    assert_html(form, "option[value='2024'][selected]")

    # License select
    assert_includes(form, :LICENSE.l)
    assert_includes(form, "Creative Commons")
    assert_includes(form, "Public Domain")
  end

  def test_upload_fields_with_custom_label
    observation = observations(:minimal_unknown_obs)

    form = render_upload_form(observation) do
      upload_fields(
        file_field_label: "Custom Label:",
        copyright_holder: "User",
        copyright_year: 2024,
        licenses: [["CC", 1]],
        upload_license_id: 1
      )
    end

    assert_includes(form, "Custom Label:")
  end

  # Image namespace tests
  def test_image_namespace_creates_nested_fields
    observation = observations(:minimal_unknown_obs)

    form = render_upload_form(observation) do
      image_namespace(:good_image, 123) do |ns|
        render(ns.field(:notes).text(wrapper_options: { label: "Notes" }))
      end
    end

    # Should create nested param structure: observation[good_image][123][notes]
    assert_html(form, "input[name='observation[good_image][123][notes]']")
    assert_html(form, "input[id='observation_good_image_123_notes']")
  end

  def test_image_namespace_with_image_type
    observation = observations(:minimal_unknown_obs)

    form = render_upload_form(observation) do
      image_namespace(:image, 456) do |ns|
        render(ns.field(:when).text(wrapper_options: { label: "When" }))
      end
    end

    assert_html(form, "input[name='observation[image][456][when]']")
  end

  # FieldProxy tests
  def test_field_proxy_generates_correct_dom_attributes
    proxy = Components::ApplicationForm::FieldProxy.new(
      "observation[good_image][123]", :notes, "some notes"
    )

    assert_equal(:notes, proxy.key)
    assert_equal("some notes", proxy.value)
    assert_equal("observation_good_image_123_notes", proxy.dom.id)
    assert_equal("observation[good_image][123][notes]", proxy.dom.name)
    assert_equal("some notes", proxy.dom.value)
  end

  def test_field_proxy_with_blank_namespace
    proxy = Components::ApplicationForm::FieldProxy.new("", :field_name, "val")

    assert_equal("field_name", proxy.dom.id)
    assert_equal("field_name", proxy.dom.name)
  end

  def test_field_proxy_with_nil_value
    proxy = Components::ApplicationForm::FieldProxy.new("ns", :field, nil)

    assert_equal("", proxy.dom.value)
  end

  # image_field_proxy class method tests
  def test_image_field_proxy_creates_correct_namespace
    proxy = Components::ApplicationForm.image_field_proxy(
      :good_image, 789, :notes, "test notes"
    )

    assert_equal(:notes, proxy.key)
    assert_equal("test notes", proxy.value)
    assert_equal("observation[good_image][789][notes]", proxy.dom.name)
    assert_equal("observation_good_image_789_notes", proxy.dom.id)
  end

  def test_image_field_proxy_with_image_type
    proxy = Components::ApplicationForm.image_field_proxy(
      :image, 100, :when, "2024-01-01"
    )

    assert_equal("observation[image][100][when]", proxy.dom.name)
  end

  # Radio field tests (via Superform)
  def test_radio_field_renders_options
    form = render_form do
      radio_field(:number, [1, "Option 1"], [2, "Option 2"])
    end

    assert_html(form, "div.radio")
    assert_html(form, "input[type='radio'][name='collection_number[number]']",
                count: 2)
    assert_html(form, "input[value='1']")
    assert_html(form, "input[value='2']")
    assert_includes(form, "Option 1")
    assert_includes(form, "Option 2")
  end

  def test_radio_field_with_wrap_class
    form = render_form do
      radio_field(:number, [1, "A"], [2, "B"], wrap_class: "ml-4")
    end

    assert_html(form, "div.radio.ml-4", count: 2)
  end

  # RadioField standalone tests (via FieldProxy)
  def test_radio_field_with_field_proxy
    proxy = Components::ApplicationForm::FieldProxy.new(
      "chosen_name", :name_id
    )
    html = render(Components::ApplicationForm::RadioField.new(
                    proxy, [10, "Alpha"], [20, "Beta"],
                    wrapper_options: { wrap_class: "ml-4" }
                  ))

    assert_html(html, "div.radio.ml-4", count: 2)
    assert_html(html,
                "input[type='radio'][name='chosen_name[name_id]']",
                count: 2)
    assert_html(html, "input[id='chosen_name_name_id_10'][value='10']")
    assert_html(html, "input[id='chosen_name_name_id_20'][value='20']")
    assert_includes(html, "Alpha")
    assert_includes(html, "Beta")
  end

  def test_radio_field_proxy_with_checked_value
    proxy = Components::ApplicationForm::FieldProxy.new(
      "chosen_name", :name_id, "20"
    )
    html = render(Components::ApplicationForm::RadioField.new(
                    proxy, [10, "Alpha"], [20, "Beta"]
                  ))

    assert_html(html, "input[value='10']:not([checked])")
    assert_html(html, "input[value='20'][checked]")
  end

  # Autocompleter field tests
  def test_autocompleter_field_renders_structure
    form = render_form do
      autocompleter_field(:name, type: :name, label: "Species Name")
    end

    assert_html(form, "div.form-group")
    assert_includes(form, "Species Name")
    assert_html(form, "[data-controller*='autocompleter']")
  end

  def test_autocompleter_field_with_textarea
    form = render_form do
      autocompleter_field(:name, type: :name, textarea: true, label: "Name")
    end

    assert_html(form, "textarea")
  end

  private

  def render_form(local: true, &block)
    form = TestFormClass.new(@collection_number,
                             action: "/test_form_path",
                             local: local)
    form.field_block = block

    render(form)
  end

  def render_upload_form(model, &block)
    form = TestFormClass.new(model, action: "/test_upload_path")
    form.field_block = block

    render(form)
  end

  # Single reusable test form class to avoid duplicate view_template methods
  class TestFormClass < Components::ApplicationForm
    attr_accessor :field_block

    def view_template
      instance_eval(&field_block) if field_block
    end
  end
end
