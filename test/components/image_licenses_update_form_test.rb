# frozen_string_literal: true

require("test_helper")

# Tests for Components::ImageLicensesUpdateForm — the bulk
# image-license updater that replaces the old `form_with(scope:
# :updates)` ERB. Verifies the rendered form shape matches the
# wire contract the controller expects.
class ImageLicensesUpdateFormTest < ComponentTestCase
  def test_renders_one_table_row_per_group
    form = build_form([
                        sample_datum(holder: "Alice", license_id: 3, count: 5),
                        sample_datum(holder: "Bob", license_id: 4, count: 2)
                      ])
    html = render_form(form)

    assert_html(html, "table.table-license-updater tbody tr", count: 2)
  end

  def test_emits_field_names_under_updates_scope_per_row_index
    form = build_form([sample_datum, sample_datum])
    html = render_form(form)

    # Row 0 fields.
    assert_html(html, "input[name='updates[0][new_holder]']")
    assert_html(html, "input[name='updates[0][old_holder]'][type='hidden']")
    assert_html(html, "select[name='updates[0][new_id]']")
    assert_html(html, "input[name='updates[0][old_id]'][type='hidden']")
    # Row 1 fields.
    assert_html(html, "input[name='updates[1][new_holder]']")
    assert_html(html, "select[name='updates[1][new_id]']")
  end

  def test_inputs_carry_current_values_from_row_attributes
    form = build_form([sample_datum(holder: "Alice", license_id: 7)])
    html = render_form(form)

    assert_html(html,
                "input[name='updates[0][new_holder]'][value='Alice']")
    assert_html(html,
                "input[name='updates[0][old_holder]'][value='Alice']")
    assert_html(html,
                "input[name='updates[0][old_id]'][value='7']")
  end

  def test_renders_help_text_and_submit_button
    html = render_form(build_form([sample_datum]))

    assert_html(html, ".container-text")
    assert_html(html,
                "input[type='submit'][value='#{:image_updater_update.l}']")
  end

  def test_uses_patch_method_for_update_route
    html = render_form(build_form([sample_datum]))

    assert_html(html,
                "input[type='hidden'][name='_method'][value='patch']")
  end

  def test_omits_table_when_no_data
    html = render_form(build_form([]))

    assert_no_html(html, "table.table-license-updater")
    # Submit button still rendered (no rows, but the form shell shows).
    assert_html(html,
                "input[type='submit'][value='#{:image_updater_update.l}']")
  end

  private

  def sample_datum(holder: "Alice", license_id: 3, count: 5)
    {
      "license_count" => count,
      "copyright_holder" => holder,
      "license_id" => license_id,
      "licenses" => [["CC-BY", 1], ["CC-BY-SA", 2], ["Public Domain", 3]]
    }
  end

  def build_form(data)
    FormObject::ImageLicenseUpdates.new(data: data)
  end

  def render_form(form)
    render(Components::ImageLicensesUpdateForm.new(
             form, action: "/images/licenses"
           ))
  end
end
