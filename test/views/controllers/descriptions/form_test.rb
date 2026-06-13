# frozen_string_literal: true

require "test_helper"

# Tests for the polymorphic NameDescription / LocationDescription form.
# The form has three different source-type rendering paths (admin all-types
# select, new-record basic-types select, locked existing-record hidden field)
# and a license select whose option values must be License ids, not labels —
# this is the path that regressed in PR #4364 when SelectField switched to
# Rails-shape pairs. Coverage targets every branch and locks in the
# label/value shape of every <option> so callers can't drift again.
module Views::Controllers::Descriptions
  class FormTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      # `source_type = "public"` mirrors `initialize_description_source` —
      # the controller seeds new descriptions before rendering so the form
      # has a basic source type to display.
      @new_name_desc = NameDescription.new(name: names(:peltigera),
                                           source_type: "public")
      @existing_name_desc = name_descriptions(:peltigera_desc)
      @new_loc_desc = LocationDescription.new(location: locations(:albion),
                                              source_type: "public")
      @existing_loc_desc = location_descriptions(:albion_desc)
      @licenses = License.available_names_and_ids
      @license = License.first
    end

    def test_new_name_description_form_renders_basic_source_type_select
      html = render_form(description: @new_name_desc)

      # Form structure — id derived from model type
      assert_html(html, "form#name_description_form")
      assert_html(html, "form[action*='/names/']")
      assert_html(html, "form[action*='/descriptions']")

      # Source-type select for new, non-admin user gets the basic 3 types
      # (public, source, user) — not the full all-types list.
      assert_html(html, "select[name='description[source_type]']")
      assert_basic_source_type_options(html)

      # The submission-value of every option must be the symbolic type,
      # NOT the localized label. Regression guard for #4364: SelectField
      # now reads `[label, value]` pairs; if a caller passes the flipped
      # `[value, label]` shape by mistake, this assertion fails.
      Description::BASIC_SOURCE_TYPES.each do |type|
        assert_html(html,
                    "select[name='description[source_type]'] " \
                    "option[value='#{type}']",
                    text: :"form_description_source_#{type}".l)
      end

      # source_name (text field) and project_id (hidden)
      assert_html(html, "input[name='description[source_name]']")
      assert_html(html,
                  "input[type='hidden'][name='description[project_id]']")

      # License select: option values are License ids, option text is the
      # display name. The shape contract that broke #4358 lives here.
      assert_license_select_shape(html)

      # Permissions section — new descriptions: author and admin (creator),
      # so the checkboxes render.
      assert_html(html,
                  "input[type='checkbox']" \
                  "[name='description[public_write]']")
      assert_html(html, "input[type='checkbox'][name='description[public]']")

      # Note fields — every NameDescription note field gets a textarea.
      NameDescription.all_note_fields.each do |field|
        assert_html(html, "textarea[name='description[#{field}]']")
      end

      # Two submit buttons (top + bottom), value = CREATE for a new record.
      assert_html(html,
                  "input[type='submit'][value='#{:CREATE.l}']",
                  count: 2)
    end

    def test_admin_mode_renders_all_source_types
      stub_admin_mode!
      html = render_form(description: @new_name_desc)

      assert_all_source_type_options(html)

      # Spot-check that one of the non-basic types is present with the
      # correct value. `project` is in ALL but not BASIC.
      assert_html(html,
                  "select[name='description[source_type]'] " \
                  "option[value='project']",
                  text: :form_description_source_project.l)
    end

    def test_existing_description_locks_source_type_to_hidden_field
      # An existing description not in admin mode falls through to the
      # hidden-field branch: source_type can't be changed once set.
      html = render_form(description: @existing_name_desc)

      assert_no_html(html, "select[name='description[source_type]']")
      assert_html(html,
                  "input[type='hidden'][name='description[source_type]']")

      # Submit buttons read SAVE_EDITS, not CREATE, for an existing record.
      assert_html(html,
                  "input[type='submit'][value='#{:SAVE_EDITS.l}']",
                  count: 2)
    end

    # Regression for #4491: project/foreign descriptions show the source
    # name read-only via `.t` (textile-safe HTML). It was emitted with
    # `plain`, which re-escaped the entities, so a source name with "&"
    # rendered the double-escaped code "&amp;" instead of "&".
    def test_locked_source_name_renders_entities_not_codes
      desc = name_descriptions(:draft_boletus_edulis) # source_type: project
      desc.source_name = "Bolete & Friends"
      html = render_form(description: desc)

      # Assert the *visible* read-only source name, not the hidden input's
      # value= attribute (which carries the same string). Nokogiri's .text
      # excludes attributes and decodes entities: a correct single-encode
      # renders the literal "&", a double-escape bug renders the code "&amp;".
      source_fields = Nokogiri::HTML(html).
                      at_css("label[for='description_source']").parent
      assert_includes(source_fields.text, "Bolete & Friends")
      assert_not_includes(source_fields.text, "Bolete &amp; Friends")
    end

    def test_location_description_form
      html = render_form(description: @new_loc_desc)

      # id and action route through the locations controller.
      assert_html(html, "form#location_description_form")
      assert_html(html, "form[action*='/locations/']")
      assert_html(html, "form[action*='/descriptions']")

      # LocationDescription gets its own note-field set — different from
      # NameDescription's. No `<hr>` separator omission either; the
      # textile-help header block is name-only.
      LocationDescription.all_note_fields.each do |field|
        assert_html(html, "textarea[name='description[#{field}]']")
      end
    end

    def test_merge_opts_renders_merge_hidden_fields
      html = render_form(
        description: @existing_name_desc,
        merge_opts: { merge: true, old_desc_id: 42, delete_after: "1" }
      )

      # `render_flat_hidden_field` uses the raw name (no `description[...]`
      # wrapper) so the merge controller can read flat params.
      assert_html(html,
                  "input[type='hidden'][name='old_desc_id'][value='42']")
      assert_html(html,
                  "input[type='hidden'][name='delete_after'][value='1']")
    end

    def test_merge_opts_omitted_when_not_merging
      html = render_form(description: @existing_name_desc)

      assert_no_html(html, "input[name='old_desc_id']")
      assert_no_html(html, "input[name='delete_after']")
    end

    private

    def render_form(description:, merge_opts: {})
      # Reference the sibling class unqualified within the module.
      render(Form.new(
               description,
               licenses: @licenses,
               user: @user,
               merge_opts: merge_opts
             ))
    end

    def assert_basic_source_type_options(html)
      Description::BASIC_SOURCE_TYPES.each do |type|
        assert_html(html,
                    "select[name='description[source_type]'] " \
                    "option[value='#{type}']")
      end
      # `project` and `foreign` are in ALL but not BASIC.
      extras = Description::ALL_SOURCE_TYPES - Description::BASIC_SOURCE_TYPES
      extras.each do |t|
        assert_no_html(html,
                       "select[name='description[source_type]'] " \
                       "option[value='#{t}']")
      end
    end

    def assert_all_source_type_options(html)
      Description::ALL_SOURCE_TYPES.each do |type|
        assert_html(html,
                    "select[name='description[source_type]'] " \
                    "option[value='#{type}']",
                    text: :"form_description_source_#{type}".l)
      end
    end

    def assert_license_select_shape(html)
      # Every option's value must be the License id; its text must be the
      # License display name. This is the contract #4358 broke.
      assert_html(html, "select[name='description[license_id]']")
      assert_html(html,
                  "select[name='description[license_id]'] " \
                  "option[value='#{@license.id}']",
                  text: @license.display_name)
      # Confirm the inverse doesn't happen — there should be NO option
      # whose `value=` is the human label.
      assert_no_html(html,
                     "select[name='description[license_id]'] " \
                     "option[value='#{@license.display_name}']")
    end
  end
end
