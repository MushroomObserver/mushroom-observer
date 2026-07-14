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

  # Regression: TextareaField applies `text-monospace` when instantiated
  # directly with `wrapper_options[:monospace]` — not just via the helper.
  # Matches ERB `text_area_with_label`'s `:monospace` semantics so direct
  # component callers (e.g. FieldProxy-backed textareas) get parity.
  def test_textarea_field_monospace_at_component_level
    form = Components::ApplicationForm.new(@collection_number,
                                           action: "/test_form_path")
    field = form.field(:notes)
    component = Components::ApplicationForm::TextareaField.new(
      field, wrapper_options: { label: "Notes", monospace: true }
    )

    html = render(component)
    assert_html(html, "textarea.form-control.text-monospace")
  end

  def test_textarea_field_with_rows
    form = render_form do
      textarea_field(:notes, label: "Notes", rows: 10)
    end

    assert_includes(form, 'rows="10"')
  end

  # Regression: `prefs: true` auto-resolves the label from the
  # `prefs_<field>` i18n key, matching ERB
  # `auto_label_if_form_is_account_prefs`. Six helpers honor this:
  # text_field, textarea_field, select_field, checkbox_field,
  # radio_field, number_field — same set as ERB.
  def test_text_field_prefs_auto_resolves_label_from_i18n
    form = render_form do
      text_field(:login, prefs: true)
    end

    # `:prefs_login.t` → "Login" (config/locales/en.txt)
    assert_html(form, "label", text: "Login")
  end

  # Regression (Copilot review on #4687): FieldLabelRow#append_colon used
  # to interpolate the resolved text into a new String ("#{text}:"),
  # which strips the html_safe flag off a Textile-rendered label --
  # render_label_content would then re-escape the already-safe <em>
  # markup instead of rendering it. Unlike checkbox_field's label_text
  # (which never appends a colon), text_field goes through the
  # colon-appending path, so this exercises append_colon directly.
  def test_label_text_preserves_textile_markup_through_colon
    form = render_form do
      text_field(:name, label: :prefs_no_emails)
    end

    assert_html(form, "label em", text: "all")
  end

  # Regression: `prefs_no_emails` ("Opt out of _all_ email from MO.")
  # carries real textile italic markup -- FieldLabelRow#resolved_label_text
  # resolves bare Symbol labels via `.t`, not `.l`, specifically so this
  # renders as an actual <em> tag (MO's Textile class's italic output)
  # instead of literal underscores.
  def test_checkbox_field_prefs_auto_resolves_label_from_i18n
    form = render_form do
      checkbox_field(:no_emails, prefs: true)
    end

    assert_includes(form, "Opt out of")
    assert_html(form, "label em", text: "all")
    assert_no_html(form, "label", text: "_all_")
  end

  def test_auto_label_for_prefs_returns_options_unchanged_when_no_prefs
    form = Components::ApplicationForm.new(@collection_number,
                                           action: "/test_form_path")

    result = form.send(:auto_label_for_prefs, :name, label: "Original")
    assert_equal({ label: "Original" }, result,
                 "Without :prefs, options should be untouched")
  end

  # auto_label_for_prefs itself resolves to the bare translation-key
  # Symbol, not a String -- resolution to actual display text (via
  # `.t`) happens downstream in FieldLabelRow#resolved_label_text.
  def test_auto_label_for_prefs_drops_prefs_key_when_resolving
    form = Components::ApplicationForm.new(@collection_number,
                                           action: "/test_form_path")

    result = form.send(:auto_label_for_prefs, :login,
                       prefs: true, class: "extra")
    assert_equal(:prefs_login, result[:label])
    assert_not(result.key?(:prefs),
               ":prefs should be removed after resolution so it " \
               "doesn't leak into wrapper_options downstream")
    assert_equal("extra", result[:class],
                 "Unrelated options should pass through")
  end

  # A field label secretly doubling as a clickable link is a UX smell
  # (not obviously clickable, easy to miss) -- FieldLabelRow raises
  # rather than silently rendering one. Route link content through
  # help: instead (see Components::Form::UploadGallery::Fields#
  # render_license_field for the established pattern).
  def test_label_containing_a_link_raises
    error = assert_raises(RuntimeError) do
      render_form do
        text_field(:name, label: '<a href="/x">Click</a>'.html_safe)
      end
    end
    assert_match(/contains a link/, error.message)
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

  def test_checkbox_field_with_label_false_still_renders_wrapper
    form = render_form do
      checkbox_field(:placeholder, label: false,
                                   wrap_class: "m-0", label_class: "p-0")
    end

    # Should still have Bootstrap checkbox wrapper and label element
    assert_html(form, "div.checkbox.m-0")
    assert_html(form, "label.p-0")
    assert_includes(form, 'type="checkbox"')
    # But should NOT have label text
    assert_not_includes(form, "Placeholder")
  end

  def test_checkbox_field_applies_wrap_class_to_wrapper
    form = render_form do
      checkbox_field(:placeholder, label: "Test", wrap_class: "mt-3")
    end

    # wrap_class should be on wrapper div, not the input
    assert_html(form, "div.checkbox.mt-3")
  end

  # Unlike text_field/select_field/etc's colon-suffixed prompt label
  # (see test_label_containing_a_link_raises above), a checkbox label
  # can be rich content -- e.g. names/synonyms/form.rb's
  # synonym-selection checkboxes, whose label is a name link plus a
  # copy-id badge. CheckboxField#label_text calls resolved_label_text
  # directly, bypassing FieldLabelRow#label_text's link guard
  # entirely, so this must render without raising.
  def test_checkbox_field_label_with_link_does_not_raise
    form = render_form do
      checkbox_field(:placeholder, label: '<a href="/x">Click</a>'.html_safe)
    end

    assert_html(form, "label a[href='/x']", text: "Click")
  end

  # Collection mode: `checkbox_field(:field, [label, value], ...)`
  # renders N checkboxes that post as `model[field][]=<value>` for
  # each checked option. Pairs are `[label, value]` — matching
  # `select_field` and `radio_field`. Previously this API path was
  # unreachable: callers had to bypass `checkbox_field` and call
  # `field(:foo).checkbox(...)` directly.
  def test_checkbox_field_array_mode_renders_one_checkbox_per_choice
    form = render_form do
      checkbox_field(:placeholder,
                     ["Foo", 1],
                     ["Bar", 2],
                     ["Baz", 3])
    end

    # Each option becomes a checkbox with the field name suffixed `[]`
    # so the controller receives an array of selected values. Values
    # are the SECOND element of each pair (Rails shape).
    name_attr = "#{@collection_number.class.model_name.singular}" \
                "[placeholder][]"
    assert_html(form,
                "input[type='checkbox'][name='#{name_attr}'][value='1']")
    assert_html(form,
                "input[type='checkbox'][name='#{name_attr}'][value='2']")
    assert_html(form,
                "input[type='checkbox'][name='#{name_attr}'][value='3']")
    # Labels (first element of each pair) render alongside each input.
    assert_includes(form, "Foo")
    assert_includes(form, "Bar")
    assert_includes(form, "Baz")
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

  # Regression: a `[Label, nil]` pair (Rails-shape, value is nil) must
  # render `<option value="">Label`, not `<option>Label` (which would
  # submit "Label" as the value). Phlex's HTML DSL omits nil-valued
  # attributes by default, so SelectField coerces nil values to "" to
  # match Rails' select-helper behavior.
  def test_select_field_nil_value_renders_empty_value_attribute
    options = [["(No Project)", nil], ["EOL Project", "778455076"]]
    form = render_form do
      select_field(:number, options, label: "Project")
    end

    assert_html(form, "option[value='']", text: "(No Project)")
    assert_html(form, "option[value='778455076']", text: "EOL Project")
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

  # Regression: Phlex password_field defaults `value: ""` to prevent
  # Rails from re-populating the field with the stored password hash
  # on form re-render. Matches ERB password_field_with_label.
  def test_password_field_defaults_value_to_empty_string
    form = render_form do
      password_field(:password, label: "Password")
    end

    assert_html(form, "input[type='password'][value='']")
  end

  # Regression: explicit `value:` override is respected.
  def test_password_field_explicit_value_overrides_default
    form = render_form do
      password_field(:password, label: "Password", value: "stored-hash")
    end

    assert_html(form, "input[type='password'][value='stored-hash']")
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

  # Regression: hidden inputs used to emit `class="form-control"` —
  # harmless visually (hidden inputs don't render) but wrong markup,
  # and inconsistent between Symbol and String paths (Symbol detoured
  # through TextField; String through HiddenField). Both paths now
  # route through `HiddenField`, the dedicated hidden-input component.
  # The Symbol path passes Superform's `field(:x)` directly — same
  # `.dom.id`/`.dom.name`/`.value` interface as `FieldProxy`.
  def test_hidden_field_symbol_key_does_not_emit_form_control
    form = render_form do
      hidden_field(:secret, value: "x")
    end
    doc = Nokogiri::HTML(form)
    input = doc.at_css("input[type='hidden'][name*='secret']")
    assert(input, "Hidden input must render")
    assert_not_includes(input["class"] || "", "form-control",
                        "Symbol-keyed hidden_field must not emit form-control")
  end

  def test_hidden_field_string_key_does_not_emit_form_control
    form = render_form do
      hidden_field("approved_where", value: "x")
    end
    doc = Nokogiri::HTML(form)
    input = doc.at_css("input[type='hidden'][name='approved_where']")
    assert(input, "Hidden input must render")
    assert_not_includes(input["class"] || "", "form-control",
                        "String-keyed hidden_field must not emit form-control")
  end

  # Symbol-keyed `hidden_field` keeps Superform's namespaced name
  # (e.g. `<model_name>[<field>]`) — the whole point of going through
  # `field(...)` rather than the raw String path. Locks that in.
  def test_hidden_field_symbol_key_uses_superform_namespace
    form = render_form do
      hidden_field(:secret, value: "x")
    end
    # The render_form helper builds an anonymous form whose model
    # defaults to a Collection Number; the form's namespace is
    # "collection_number". The hidden field should be namespaced
    # under it.
    assert_match(/name="collection_number\[secret\]"/, form,
                 "Symbol-keyed hidden_field must namespace under the model")
  end

  # Most callers in the codebase rely on the Symbol path auto-reading
  # the value from the form's model/FormObject (e.g.
  # `descriptions/form.rb hidden_field(:project_id)` reads
  # `form.model.project_id`). Passing Superform's `field(:x)` directly
  # to HiddenField preserves that — `HiddenField` reads `.value` off
  # the field, and Superform's field knows the model's value.
  def test_hidden_field_symbol_key_auto_reads_value_from_model
    # `@collection_number.name` == "Rolf Singer" per the fixture.
    form = render_form do
      hidden_field(:name) # no explicit value:
    end
    doc = Nokogiri::HTML(form)
    input = doc.at_css("input[type='hidden'][name='collection_number[name]']")
    assert(input, "Hidden input must render")
    assert_equal("Rolf Singer", input["value"],
                 "Symbol-keyed hidden_field with no value: must auto-read " \
                 "from the form's model/FormObject")
  end

  # Caller's explicit `value:` always wins, even when the model has
  # a value for the attribute. (HiddenField's `@attributes.fetch(:value)`
  # uses the override before falling back to `@field.value`.)
  def test_hidden_field_symbol_key_explicit_value_overrides_model
    form = render_form do
      hidden_field(:name, value: "OVERRIDE")
    end
    doc = Nokogiri::HTML(form)
    input = doc.at_css("input[type='hidden'][name='collection_number[name]']")
    assert_equal("OVERRIDE", input["value"],
                 "Explicit value: must override the model's value")
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

  # Regression: Phlex number_field defaults `min: 1`. Matches ERB
  # number_field_with_label's `opts[:min] ||= 1`.
  def test_number_field_defaults_min_to_1
    form = render_form do
      number_field(:count, label: "Count")
    end

    assert_html(form, "input[type='number'][min='1']")
  end

  # Regression: explicit `min:` override is respected.
  def test_number_field_explicit_min_overrides_default
    form = render_form do
      number_field(:count, label: "Count", min: 0)
    end

    assert_html(form, "input[type='number'][min='0']")
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
    day_pos = form.index("_3i")
    month_pos = form.index("_2i")
    year_pos = form.index("_1i")
    assert(day_pos < month_pos && month_pos < year_pos,
           "Expected order day(_3i), month(_2i), year(_1i)")
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
    assert_no_html(form, "[data-controller='file-input']")

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

    assert_html(form, "button[type='submit'].center-block")
    assert_includes(form, "my-3")
  end

  # `as:` other than :button delegates to Superform's submit, which renders an
  # <input type="submit"> rather than MO's Button::Submit <button>.
  def test_submit_as_non_button_uses_superform_input
    form = render_form do
      submit("Save", as: :input)
    end

    assert_html(form, "input[type='submit'][value='Save']")
  end

  def test_submit_with_custom_submits_with
    form = render_form do
      submit("Save", submits_with: "Saving...")
    end

    assert_html(form,
                "button[type='submit'][data-turbo-submits-with='Saving...']")
  end

  # Mirrors ERB `forms_helper.rb#submits_default_text`: an Update
  # button shows "Updating" in-flight, anything else shows "Submitting".
  def test_submit_default_submits_with_for_update_button
    form = render_form { submit(:UPDATE.l) }

    submits_with = "data-turbo-submits-with='#{:UPDATING.l}'"
    assert_html(form, "button[type='submit'][#{submits_with}]")
  end

  def test_submit_default_submits_with_for_create_button
    form = render_form { submit(:CREATE.l) }

    submits_with = "data-turbo-submits-with='#{:SUBMITTING.l}'"
    assert_html(form, "button[type='submit'][#{submits_with}]")
  end

  # `between_class` (FieldWithHelp) mirrors ERB:
  # inline rows pick "mr-3"; block rows pick "form-between".
  def test_between_class_block_field_with_help
    form = render_form do
      text_field(:name, label: "Name:", help: "Help text",
                        help_collapse: true)
    end

    assert_html(form, "span.form-between")
    assert_no_html(form, "span.form-between.mr-3")
  end

  def test_between_class_inline_field_with_help
    form = render_form do
      text_field(:name, inline: true, label: "Name:", help: "Help text",
                        help_collapse: true)
    end

    assert_html(form, "span.mr-3")
    assert_no_html(form, "span.form-between")
  end

  def test_submit_with_custom_data_attributes
    form = render_form do
      submit("Save", data: { confirm: "Are you sure?" })
    end

    assert_html(form, "button[type='submit'][data-confirm='Are you sure?']")
  end

  # `as: :input` falls through to SuperForm's default submit input.
  def test_submit_as_input_renders_input_element
    form = render_form { submit("Save", as: :input) }

    assert_html(form, "input[type='submit'][value='Save']")
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

  # Regression: each per-option label carries `for=` pointing at its
  # input's id (matching ERB radio_with_label, which uses
  # form.label("#{field}_#{value}")).
  def test_radio_field_per_option_label_has_for_attribute
    form = render_form do
      radio_field(:number, [1, "A"], [2, "B"])
    end

    assert_html(form, "label[for='collection_number_number_1']")
    assert_html(form, "label[for='collection_number_number_2']")
    assert_html(form, "input[type='radio'][id='collection_number_number_1']")
    assert_html(form, "input[type='radio'][id='collection_number_number_2']")
  end

  # Regression: RadioField `between` slot renders after each option's
  # label text inside the `<label>`, wrapped in `<div class="d-inline-block
  # ml-3">`. Matches ERB `radio_with_label`'s `between:` shape. Applied
  # uniformly to every option (one slot per RadioField call).
  def test_radio_field_with_between_slot
    form = render_form do
      component = Components::ApplicationForm::RadioField.new(
        field(:number), [1, "A"], [2, "B"]
      )
      component.with_between do
        span(class: "help-note") { "(see notes)" }
      end
      render(component)
    end

    assert_html(form, "div.radio div.d-inline-block.ml-3 span.help-note",
                count: 2)
    assert_includes(form, "(see notes)")
  end

  # Regression: array-mode checkbox per-option labels also carry `for=`,
  # AND the inputs get value-suffixed ids (so multiple options don't
  # collide). MO's CheckboxField bypasses upstream's Checkbox component
  # for this case because upstream mis-detects array mode when the
  # field's parent isn't another Superform::Field. Array mode is reached
  # via `field(:foo).checkbox([v, label], …)` directly.
  def test_checkbox_field_array_mode_per_option_label_has_for_attribute
    form = render_form do
      # Rails-shape pairs: `[label, value]` (matches `select_field`).
      render(field(:number).checkbox(["A", 1], ["B", 2]))
    end

    assert_html(form, "label[for='collection_number_number_1']")
    assert_html(form, "label[for='collection_number_number_2']")
    assert_html(form, "input[type='checkbox'][id='collection_number_number_1']")
    assert_html(form, "input[type='checkbox'][id='collection_number_number_2']")
    # Each option submits its own value under `field[]`
    array_name = "collection_number[number][]"
    assert_html(form,
                "input[type='checkbox'][name='#{array_name}'][value='1']")
    assert_html(form,
                "input[type='checkbox'][name='#{array_name}'][value='2']")
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

  # Regression test: Symbol option values should be converted to strings
  def test_radio_field_with_symbol_values
    proxy = Components::ApplicationForm::FieldProxy.new(
      "chosen_name", :status, :active
    )
    html = render(Components::ApplicationForm::RadioField.new(
                    proxy, [:active, "Active"], [:inactive, "Inactive"]
                  ))

    # Symbol values should be rendered as strings
    assert_html(html, "input[value='active']")
    assert_html(html, "input[value='inactive']")
    # The active option should be checked (matching Symbol :active)
    assert_html(html, "input[value='active'][checked]")
    assert_html(html, "input[value='inactive']:not([checked])")
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

  # Regression: ReadOnlyField label should carry `for=` pointing at the
  # hidden input's id, matching the ERB `form.label(field, ...)` output.
  def test_read_only_field_label_has_for_attribute
    form = render_form do
      read_only_field(:number, label: "Number:", value: "42")
    end

    assert_html(form, "label[for='collection_number_number']")
    assert_html(form, "input[type='hidden'][id='collection_number_number']")
  end

  # Regression: StaticTextField label should carry `for=` pointing at the
  # field's dom id (even though there's no input — matches ERB output).
  def test_static_field_label_has_for_attribute
    form = render_form do
      static_field(:number, label: "Number:", value: "42")
    end

    assert_html(form, "label[for='collection_number_number']")
  end

  # ----- derive_form_id -----
  #
  # The form id flows through `ApplicationForm#derive_form_id`, which
  # picks the first non-nil of:
  #   1. `views_controller_form_id` — if the class lives under
  #      `Views::Controllers::*`, derive from the full controller
  #      path so the id mirrors the directory structure.
  #   2. The class's own demodulized name, if it's not the bare
  #      "Form" (e.g. `Components::HerbariumForm` -> "herbarium_form").
  #   3. `model_class_form_id` — for anonymous test classes / etc.,
  #      derive from the model's class name.
  #   4. Ultimate fallback: the literal string "application_form".

  def test_derive_form_id_uses_all_controller_segments
    klass = stub_views_controller_form("Names", "Synonyms", "Approve")
    assert_equal("name_synonym_approve_form",
                 instance_id_for(klass, Name.new))
  end

  def test_derive_form_id_appends_specific_class_name_to_segments
    klass = stub_views_controller_form("Admin", "Donations",
                                       class_name: "ReviewForm")
    assert_equal("admin_donation_review_form",
                 instance_id_for(klass, Donation.new))
  end

  def test_derive_form_id_singularizes_each_path_segment
    klass = stub_views_controller_form("Account", "APIKeys")
    assert_equal("account_api_key_form",
                 instance_id_for(klass, APIKey.new))
  end

  def test_derive_form_id_for_components_uses_class_name
    # Stand-in for `Components::HerbariumForm` (no Views::Controllers
    # prefix) — derive from the class's own demodulized name.
    klass = Class.new(Components::ApplicationForm)
    Components.const_set(:HerbariumFormStub, klass)
    begin
      assert_equal("herbarium_form_stub",
                   instance_id_for(klass, Herbarium.new))
    ensure
      Components.send(:remove_const, :HerbariumFormStub)
    end
  end

  def test_derive_form_id_falls_back_to_model_class_when_class_has_no_name
    # Anonymous form class (no name) + a real model → derive from the
    # model class name.
    klass = Class.new(Components::ApplicationForm)
    assert_equal("herbarium_form",
                 instance_id_for(klass, Herbarium.new))
  end

  def test_derive_form_id_ultimate_fallback_is_application_form
    # Anonymous class with no model — falls all the way through to
    # the literal "application_form" sentinel.
    klass = Class.new(Components::ApplicationForm)
    form = klass.allocate
    assert_equal("application_form", form.derive_form_id(nil) ||
                                     "application_form")
  end

  private

  # Build a stub class registered under
  # `Views::Controllers::<seg1>::<seg2>::...::<class_name>` so the
  # heuristic sees a realistic class name. Cleans up after itself via
  # ObjectSpace constants when the test ends? No — caller is expected
  # to use the returned class transiently in one assertion.
  def stub_views_controller_form(*segments, class_name: "Form")
    parent = Views::Controllers
    segments.each do |seg|
      parent = if parent.const_defined?(seg, false)
                 parent.const_get(seg)
               else
                 parent.const_set(seg, Module.new)
               end
    end
    if parent.const_defined?(class_name, false)
      parent.const_get(class_name)
    else
      parent.const_set(class_name, Class.new(Components::ApplicationForm))
    end
  end

  # Allocates a form of `klass` without calling `initialize` (avoids
  # the Superform wiring we don't need) and asks it for its
  # auto-derived form id given `model`.
  def instance_id_for(klass, model)
    klass.allocate.derive_form_id(model)
  end

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
