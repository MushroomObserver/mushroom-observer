# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Projects
  class FormTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
    end

    def test_new_form
      html = render_form(model: Project.new)

      # Form action
      assert_html(html, "form[action='/projects']")

      # Submit button
      assert_html(html, "button[type='submit']", text: :create.ti)

      # Fields
      assert_html(html,
                  "input[type='checkbox'][name='project[open_membership]']")
      assert_html(html, "input[name='project[title]']")
      assert_html(html, "textarea[name='project[summary]']")
      assert_html(html, "input[name='project[field_slip_prefix]']")
      assert_html(html, "input[name='project[place_name]']")

      # Summary help is collapsed behind a help-trigger icon, not
      # always visible.
      assert_includes(html, :shared_textile_help.l)
      assert_html(html,
                  "a.info-collapse-trigger[href='#project_summary_help']")

      # Date Range section's explanatory text is always visible, not
      # collapsed -- this page is used rarely enough that hiding it
      # behind a trigger wasn't worth it.
      assert_includes(html, :form_projects_date_range.t)
      assert_includes(html, :form_projects_dates_explain.t)
      assert_no_html(html,
                     "a.info-collapse-trigger[href='#project_dates_help']")

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

      # Radio labels
      assert_html(html, "label[for='project_dates_any_false']",
                  text: :form_projects_enforce_date_range.t)
      assert_html(html, "label[for='project_dates_any_true']",
                  text: :form_projects_accept_any_dates.t)

      # "Accept any dates" is the default, and listed first.
      assert_html(html,
                  "input[type='radio']" \
                  "[name='project[dates_any]']" \
                  "[value='true'][checked]")
      doc = Nokogiri::HTML5.fragment(html)
      radio_values =
        doc.css("input[name='project[dates_any]']").pluck("value")
      assert_equal(%w[true false], radio_values)

      # Date fields are collapsed by default (Accept any dates selected).
      assert_html(html, "[data-collapse-switch-type='false'].collapse")
      assert_no_html(html, "[data-collapse-switch-type='false'].collapse.in")

      # No upload fields without upload_params
      assert_no_html(html, "input[type='file']")
    end

    def test_existing_record_form
      project = projects(:bolete_project)
      html = render_form(model: project)

      assert_html(html,
                  "form[action='/projects/#{project.id}']")
      assert_html(html,
                  "button[type='submit']", text: :save_edits.ti)
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
      # "Enforce date range" selected -- date fields are expanded.
      assert_html(html, "[data-collapse-switch-type='false'].collapse.in")
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
      render(Form.new(
               model,
               enctype: "multipart/form-data",
               dates_any: dates_any,
               upload_params: upload_params
             ))
    end
  end
end
