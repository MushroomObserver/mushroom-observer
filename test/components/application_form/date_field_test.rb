# frozen_string_literal: true

require "test_helper"

# Tests for the `date_field` ApplicationForm helper.
class DateFieldTest < ComponentTestCase
  include ApplicationFormFieldTestHelpers

  def setup
    @collection_number = collection_numbers(:coprinus_comatus_coll_num)
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

    # Verify order: day, month, year (3i before 2i before 1i). Scoped
    # to the date-selects wrapper's own children via Nokogiri element
    # order, not a substring search over the whole form -- the
    # authenticity_token hidden field is a random per-render value
    # that can coincidentally contain "_1i"/"_2i"/"_3i".
    date_selects = Nokogiri::HTML5.fragment(form).at_css("div.date-selects")
    field_ids = date_selects.css("select, input").pluck("id")
    assert_equal(
      %w[collection_number_when_3i collection_number_when_2i
         collection_number_when_1i],
      field_ids,
      "Expected order day(_3i), month(_2i), year(_1i)"
    )
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

  # Regression: date_field's inline: propagates to both the outer
  # form-group AND the inner date-selects div, so the label sits next
  # to the day/month/year inputs instead of breaking onto its own line.
  def test_date_field_inline_adds_form_inline_to_outer_wrap
    form = render_comment_form do
      date_field(:created_at, inline: true, label: "When:")
    end

    assert_html(form, "div.form-group.form-inline")
    assert_html(form, "div.date-selects.d-inline-block")
  end

  # Regression: date_field's between: renders inside the label row
  # (before the date-selects), not as a separate row or a trailing
  # sibling -- FieldLabelRow handles this via
  # wrapper_options[:between].
  def test_date_field_between_renders_inline_with_label
    form = render_comment_form do
      date_field(:created_at, label: "When:", between: "(picker note)")
    end

    assert_includes(form, "(picker note)")

    between_pos = form.index("(picker note)")
    selects_pos = form.index("date-selects")
    assert(between_pos && selects_pos,
           "both between content and date-selects should be present")
    assert(between_pos < selects_pos,
           "between content must render in the label row " \
           "(before the date-selects)")
  end
end
