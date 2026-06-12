# frozen_string_literal: true

require("test_helper")

# Test form helpers
class FormsHelperTest < ActionView::TestCase
  def test_file_field_with_label_has_accept_attribute
    # Create a minimal form builder for testing
    form = ActionView::Helpers::FormBuilder.new(
      :upload, nil, self, {}
    )

    html = file_field_with_label(
      form: form,
      field: :image,
      label: "Upload Image"
    )

    # Should have accept="image/*" attribute to restrict file picker to images
    assert_includes(html, 'accept="image/*"',
                    "File input should have accept attribute for images")
  end

  def test_file_field_with_label_has_file_input_controller
    form = ActionView::Helpers::FormBuilder.new(
      :upload, nil, self, {}
    )

    html = file_field_with_label(
      form: form,
      field: :image,
      label: "Upload Image"
    )

    # Should have Stimulus controller for client-side validation
    assert_includes(html, 'data-controller="file-input"',
                    "Should have file-input Stimulus controller")
    # HTML escapes > to &gt; in attributes
    assert_includes(html, "change-&gt;file-input#validate",
                    "Should trigger validation on change")
  end

  # Regression: label `for=` must match the id Rails' `radio_button`
  # generates. Rails' internal `sanitized_value` lowercases the value,
  # replaces whitespace with underscores, and strips other non-word
  # chars; values like "Hello World" or symbols with special chars
  # would otherwise produce a `for=` that doesn't match the input id.
  def test_radio_with_label_for_attr_matches_sanitized_radio_button_id
    form = ActionView::Helpers::FormBuilder.new(
      :widget, nil, self, {}
    )

    # Mixed-case value with whitespace — exercises the sanitization
    html = radio_with_label(
      form: form, field: :flavor, value: "Hello World", label: "Pick one"
    )

    # Rails sanitizes "Hello World" → "hello_world" for the input id;
    # our label `for=` uses `parameterize(separator: "_")` to match.
    assert_match(/type="radio"[^>]+id="widget_flavor_hello_world"/, html,
                 "Radio input id should be Rails-sanitized form of value")
    assert_match(/<label[^>]+for="widget_flavor_hello_world"/, html,
                 "Label `for=` must match the radio input's sanitized id")
  end

  # Simpler symbol-value case — the common pattern in MO callers
  # (e.g. :txt, :rtf, :csv from species_lists/downloads).
  def test_radio_with_label_for_attr_with_symbol_value
    form = ActionView::Helpers::FormBuilder.new(
      :report, nil, self, {}
    )

    html = radio_with_label(
      form: form, field: :type, value: :txt, label: "Plain Text"
    )

    assert_match(/type="radio"[^>]+id="report_type_txt"/, html)
    assert_match(/<label[^>]+for="report_type_txt"/, html)
  end

  # Regression: number_field_with_label uses the flex `text_label_row`
  # so a help-button / between / label_end ride next to the label,
  # matching `text_field_with_label`.
  # `between:` content rides next to the label inside a wrap div, but
  # the wrap is `<div>` (not `<div class="d-flex justify-content-between">`)
  # when there's no `label_end:` — flex-between is meaningless without a
  # right-side counterpart. See the matching `text_label_row` branch.
  def test_number_field_with_label_uses_label_row
    form = ActionView::Helpers::FormBuilder.new(
      :user, nil, self, {}
    )

    html = number_field_with_label(
      form: form, field: :layout_count, label: "Layout count",
      between: "(per page)"
    )

    assert_no_match(/<div class="d-flex justify-content-between">/, html)
    assert_match(%r{<label[^>]+>Layout count</label>}, html)
    assert_includes(html, "(per page)")
  end

  def test_number_field_with_label_defaults_min_to_1
    form = ActionView::Helpers::FormBuilder.new(
      :user, nil, self, {}
    )

    html = number_field_with_label(
      form: form, field: :layout_count, label: "Layout count"
    )

    # Attribute order is Rails-dependent; assert both attrs present on
    # the same input tag without pinning their order.
    assert_match(/<input[^>]+min="1"/, html)
    assert_match(/<input[^>]+type="number"/, html)
  end

  # `between:` only (no `label_end:`) goes inline next to the label
  # in a plain `<div>` — no d-flex/justify-content-between wrap
  # (which would orphan the label since there's no right-side content).
  def test_password_field_with_label_uses_label_row
    form = ActionView::Helpers::FormBuilder.new(
      :user, nil, self, {}
    )

    html = password_field_with_label(
      form: form, field: :password, label: "Password",
      between: "(at least 8 chars)"
    )

    assert_no_match(/<div class="d-flex justify-content-between">/, html)
    assert_match(%r{<label[^>]+>Password</label>}, html)
    assert_includes(html, "(at least 8 chars)")
  end

  # When `label_end:` is present, ERB *does* use d-flex/
  # justify-content-between to space the label area (left) and
  # label_end content (right) — the canonical use of the flex wrap.
  def test_text_label_row_uses_d_flex_when_label_end_present
    form = ActionView::Helpers::FormBuilder.new(
      :user, nil, self, {}
    )

    html = password_field_with_label(
      form: form, field: :password, label: "Password",
      label_end: '<a href="#">Forgot?</a>'.html_safe
    )

    assert_match(/<div class="d-flex justify-content-between">/, html)
    assert_includes(html, 'href="#"')
    assert_includes(html, "Forgot?")
  end

  # `select_with_label`'s `selected:` and `include_blank:` kwargs are
  # Rails `select`-helper options — they must NOT leak onto the
  # `<select>` element itself as invalid HTML attributes.
  def test_select_with_label_does_not_leak_select_helper_opts
    form = ActionView::Helpers::FormBuilder.new(
      :user, nil, self, {}
    )

    html = select_with_label(
      form: form, field: :locale, label: "Locale",
      options: [%w[English en], %w[French fr]],
      selected: "fr", include_blank: true
    )

    assert_no_match(/<select[^>]+\bselected=/, html,
                    "selected:` must not leak onto the <select> tag")
    assert_no_match(/<select[^>]+\binclude_blank=/, html,
                    "include_blank:` must not leak onto the <select> tag")
    # But the option for "fr" must still be marked selected, and the
    # blank option must be present — confirming the kwargs were routed
    # through select_opts, not stripped wholesale.
    assert_match(/<option selected="selected" value="fr">French/, html)
    assert_match(/<option value="" /, html)
  end

  def test_password_field_with_label_defaults_value_to_empty_string
    form = ActionView::Helpers::FormBuilder.new(
      :user, nil, self, {}
    )

    html = password_field_with_label(
      form: form, field: :password, label: "Password"
    )

    assert_match(/<input[^>]+value=""/, html)
    assert_match(/<input[^>]+type="password"/, html)
  end

  # Line 20: early return when `form:` is not a FormBuilder
  def test_submit_button_returns_button_text_when_form_is_not_a_builder
    result = submit_button(form: "not a builder", button: "Save")

    assert_equal("Save", result,
                 "Expected raw button label when form is not a FormBuilder")
  end

  # Line 40: :UPDATE.l button → submits_with text is :UPDATING.l
  def test_submit_button_uses_updating_text_for_update_label
    form = ActionView::Helpers::FormBuilder.new(:user, nil, self, {})

    html = submit_button(form: form, button: :UPDATE.l)

    assert_match(
      /data-turbo-submits-with="#{Regexp.escape(:UPDATING.l)}"/,
      html,
      "Update submit button should carry UPDATING text in submits-with attr"
    )
  end

  # Line 140: radio_with_label with between: renders d-inline-block wrapper
  def test_radio_with_label_renders_between_in_inline_block_div
    form = ActionView::Helpers::FormBuilder.new(:widget, nil, self, {})

    html = radio_with_label(
      form: form, field: :flavor, value: :vanilla, label: "Vanilla",
      between: "(recommended)"
    )

    assert_match(/<div class="d-inline-block ml-3">/, html,
                 "Expected d-inline-block wrapper for between: content")
    assert_includes(html, "(recommended)",
                    "Expected between: content rendered inside wrapper")
  end

  # text_area_with_label — basic render
  def test_text_area_with_label_renders_textarea_and_label
    form = ActionView::Helpers::FormBuilder.new(:observation, nil, self, {})

    html = text_area_with_label(form: form, field: :notes, label: "Notes")

    assert_match(/<textarea[^>]+name="observation\[notes\]"/, html,
                 "Expected textarea with correct name attribute")
    assert_match(%r{<label[^>]+>Notes</label>}, html,
                 "Expected label element for field")
  end

  # text_area_with_label — monospace: true adds text-monospace class
  def test_text_area_with_label_adds_monospace_class_when_requested
    form = ActionView::Helpers::FormBuilder.new(:observation, nil, self, {})

    html = text_area_with_label(
      form: form, field: :notes, label: "Notes", monospace: true
    )

    assert_match(/<textarea[^>]+class="form-control text-monospace"/, html,
                 "Expected text-monospace class on textarea")
  end

  # Lines 281-282: select_year_default_options populates options from range
  def test_select_with_label_generates_year_options_from_range
    form = ActionView::Helpers::FormBuilder.new(:obs, nil, self, {})

    html = select_with_label(
      form: form, field: :year, label: "Year",
      start_year: 2020, end_year: 2022
    )

    assert_match(%r{<option[^>]*>2022</option>}, html,
                 "Expected end_year as an option")
    assert_match(%r{<option[^>]*>2020</option>}, html,
                 "Expected start_year as an option")
  end

  # Lines 414-415: auto_label_if_form_is_account_prefs infers label from key
  def test_check_box_with_label_auto_populates_label_from_prefs
    form = ActionView::Helpers::FormBuilder.new(:user, nil, self, {})

    html = check_box_with_label(form: form, field: :no_emails, prefs: true)

    assert_includes(html, :prefs_no_emails.t,
                    "Expected label text derived from prefs_ translation key")
  end

  # text_area_with_label — append: content appears after the textarea
  def test_text_area_with_label_renders_append_content
    form = ActionView::Helpers::FormBuilder.new(:observation, nil, self, {})

    html = text_area_with_label(
      form: form, field: :notes, label: "Notes",
      append: tag.span("Hint", id: "hint")
    )

    assert_match(%r{<span id="hint">Hint</span>}, html,
                 "Expected appended content rendered after the textarea")
  end
end
