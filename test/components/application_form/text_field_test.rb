# frozen_string_literal: true

require "test_helper"

# Tests for the `text_field` ApplicationForm helper.
class TextFieldTest < ComponentTestCase
  include ApplicationFormFieldTestHelpers

  def setup
    @collection_number = collection_numbers(:coprinus_comatus_coll_num)
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

  # A field label secretly doubling as a clickable link is a UX smell
  # (not obviously clickable, easy to miss) -- FieldLabelRow strips the
  # link rather than rendering one. Route link content through help:
  # instead (see Components::Form::UploadGallery::Fields#
  # render_license_field for the established pattern). Must not raise:
  # this runs on every translated label, for every locale, on every
  # request -- a translator's textile link syntax must degrade
  # gracefully, not crash the page.
  def test_label_containing_a_link_strips_it_keeping_the_text
    form = render_form do
      text_field(:name, label: '<a href="/x">Click here</a>'.html_safe)
    end

    assert_includes(form, "Click here")
    assert_not_includes(form, "<a")
  end

  def test_label_containing_a_link_notifies_without_raising
    notified = []
    ExceptionNotifier.stub(:notifiers, [:slack]) do
      ExceptionNotifier.stub(
        :notify_exception, ->(exception, **_opts) { notified << exception }
      ) do
        render_form do
          text_field(:name, label: '<a href="/x">Click here</a>'.html_safe)
        end
      end
    end

    assert_equal(1, notified.length)
    assert_match(/contains a link/, notified.first.message)
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

  # Custom class name test
  def test_text_field_with_custom_class_name
    form = render_form do
      text_field(:name, label: "Name", class_name: "custom-wrapper")
    end

    assert_includes(form, "custom-wrapper")
  end

  # Test field with inferred label (humanized field name)
  def test_text_field_with_inferred_label
    form = render_form do
      text_field(:collection_name)
    end

    # Field name :collection_name should be humanized to "Collection name"
    assert_includes(form, "Collection name")
  end

  def test_text_field_accepts_string_name
    form = render_comment_form do
      text_field("member[lat]", value: "39.2", label: "Lat:")
    end

    assert_html(form, "input[type='text'][name='member[lat]'][value='39.2']")
  end

  def test_text_field_symbol_with_value_overrides_model
    form = render_comment_form(Comment.new(summary: "from-model")) do
      text_field(:summary, value: "from-caller", label: "Summary:")
    end

    assert_html(form, "input[name='comment[summary]'][value='from-caller']")
  end
end
