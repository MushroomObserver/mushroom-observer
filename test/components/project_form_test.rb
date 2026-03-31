# frozen_string_literal: true

require "test_helper"

class ProjectFormTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
  end

  def test_new_form
    html = render_form(model: Project.new)

    # Form action
    assert_html(html, "form[action='/projects']")

    # Submit button
    assert_html(html, "input[type='submit'][value='#{:CREATE.l}']")

    # Fields
    assert_html(html,
                "input[type='checkbox'][name='project[open_membership]']")
    assert_html(html, "input[name='project[title]']")
    assert_html(html, "textarea[name='project[summary]']")
    assert_html(html, "input[name='project[field_slip_prefix]']")
    assert_html(html, "input[name='project[place_name]']")

    # Date fields — assert both IDs and name attributes
    # Year is a text input (1i), month (2i) and day (3i) are selects
    assert_html(html,
                "input[name='project[start_date(1i)]']")
    assert_html(html,
                "select[name='project[start_date(2i)]']")
    assert_html(html,
                "select[name='project[start_date(3i)]']")
    assert_html(html,
                "input[name='project[end_date(1i)]']")
    assert_html(html,
                "select[name='project[end_date(2i)]']")
    assert_html(html,
                "select[name='project[end_date(3i)]']")

    # Radio buttons — verify name, value, and checked state
    assert_html(html,
                "input[type='radio']" \
                "[name='project[dates_any]'][value='false']")
    assert_html(html,
                "input[type='radio']" \
                "[name='project[dates_any]'][value='true']")

    # "Any" selected by default
    assert_html(html,
                "input[type='radio']" \
                "[name='project[dates_any]']" \
                "[value='true'][checked]")

    # No upload fields without upload_params
    assert_no_html(html, "input[type='file']")
  end

  def test_existing_record_form
    project = projects(:bolete_project)
    html = render_form(model: project)

    assert_html(html,
                "form[action='/projects/#{project.id}']")
    assert_html(html,
                "input[type='submit'][value='#{:SAVE_EDITS.l}']")
  end

  def test_dates_any_false
    html = render_form(model: Project.new, dates_any: false)

    assert_html(
      html,
      "input[type='radio'][name='project[dates_any]']" \
      "[value='false'][checked]"
    )
    assert_no_html(
      html,
      "input[type='radio'][name='project[dates_any]']" \
      "[value='true'][checked]"
    )
  end

  def test_with_upload_params
    license = @user.license
    html = render_form(model: Project.new, upload_params: {
                         copyright_holder: @user.legal_name,
                         copyright_year: 2026,
                         licenses: License.available_names_and_ids(license),
                         upload_license_id: license.id
                       })

    assert_html(html,
                "input[type='file'][name='project[upload][image]']")
  end

  private

  def render_form(model:, dates_any: true, upload_params: nil)
    User.current = @user
    render(Components::ProjectForm.new(
             model,
             enctype: "multipart/form-data",
             dates_any: dates_any,
             upload_params: upload_params
           ))
  end
end
