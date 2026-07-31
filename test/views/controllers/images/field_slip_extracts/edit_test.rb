# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Images::FieldSlipExtracts
  class EditTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      @obs = observations(:minimal_unknown_obs)
      @image = images(:in_situ_image)
      @obs.images << @image unless @obs.images.include?(@image)
      @project = projects(:eol_project)
    end

    def extract_with(fields: {}, confidence: {})
      FieldSlipExtract.record(
        image: @image, user: @user, prompt_version: "1",
        result: FieldSlip::Extractor::Result.new(
          provider: "gemini", model: "gemini-3.6-flash", raw: {},
          fields: fields, confidence: confidence
        )
      )
    end

    def render_page(**)
      render(Edit.new(extract: extract_with(**), observation: @obs,
                      user: @user))
    end

    def test_renders_a_row_per_field_read
      html = render_page(fields: { "Collector" => "Scott Shapiro",
                                   "Substrate" => "wood" })

      assert_html(html, "input[name='value[Collector]'][value='Scott Shapiro']")
      assert_html(html, "input[name='value[Substrate]'][value='wood']")
      assert_html(html, "input[name='use[Collector]']")
    end

    def test_omits_fields_the_model_read_nothing_for
      html = render_page(fields: { "Collector" => "Scott Shapiro" })

      assert_no_html(html, "input[name='value[Substrate]']")
    end

    # The name gets an autocompleter, which only renders its dropdown
    # and hidden id field when it has a real label -- `label: false`
    # silently drops the append slot they live in.
    def test_name_row_renders_a_live_autocompleter
      html = render_page(fields: { FieldSlip::Extractor::NAME_FIELD =>
                                   "Coprinus comatus" })

      assert_html(html, "[data-controller='autocompleter--name']")
      assert_html(html,
                  "[data-controller='autocompleter--name'] input[type=hidden]")
      assert_html(html, "label[for*='value_ID']")
    end

    # Ticked only when the ID already resolves to a name MO holds, so
    # creating a Name is always a deliberate act.
    def test_name_tick_defaults_on_for_a_known_name
      html = render_page(fields: { FieldSlip::Extractor::NAME_FIELD =>
                                   "Coprinus comatus" })

      assert_html(html, "input[name='use[ID]'][checked]")
    end

    def test_name_tick_defaults_off_for_an_unknown_name
      html = render_page(fields: { FieldSlip::Extractor::NAME_FIELD =>
                                   "Lumpy Bracket" })

      assert_html(html, "input[name='use[ID]']")
      assert_no_html(html, "input[name='use[ID]'][checked]")
    end

    def test_name_section_offers_a_confidence_menu
      html = render_page(fields: { FieldSlip::Extractor::NAME_FIELD =>
                                   "Coprinus comatus" })

      assert_html(html, "select[name='vote']")
    end

    def test_no_name_section_when_nothing_was_read_for_it
      html = render_page(fields: { "Collector" => "Scott Shapiro" })

      assert_no_html(html, "#field_slip_extract_name")
    end

    # A field the observation already has starts unticked, so applying
    # the form cannot silently overwrite a person's entry.
    def test_conflicting_row_starts_unticked
      @obs.update!(collector: "Someone Else")

      html = render_page(fields: { "Collector" => "Scott Shapiro" })

      assert_no_html(html, "input[name='use[Collector]'][checked]")
      assert_includes(html, "Someone Else")
    end

    def test_empty_current_value_ticks_by_default
      @obs.update!(collector: nil)

      html = render_page(fields: { "Collector" => "Scott Shapiro" })

      assert_html(html, "input[name='use[Collector]'][checked]")
    end

    # ---------- flags ----------

    def test_flags_a_code_that_disagrees_with_the_attached_slip
      html = render_page(fields: { "Field Slip Code" => "NEMF-99999" })

      assert_includes(html, "NEMF-99999")
      assert_includes(html, @obs.field_slip.code)
    end

    def test_no_code_flag_when_they_agree
      html = render_page(fields: { "Field Slip Code" => @obs.field_slip.code })

      assert_no_html(html, ".alert-danger")
    end

    # Naming the undefined abbreviation is what lets an admin add it,
    # which then improves every later slip.
    def test_flags_an_undefined_location_abbreviation
      @project.observations << @obs unless @project.observations.include?(@obs)

      html = render_page(fields: { "Location" => "EB2" })

      assert_includes(html, "EB2")
      assert_html(html, "a[href*='aliases/new']")
    end

    def test_no_alias_flag_for_a_known_abbreviation
      @project.observations << @obs unless @project.observations.include?(@obs)
      ProjectAlias.create!(project: @project, name: "EB2",
                           target: locations(:albion))

      html = render_page(fields: { "Location" => "EB2" })

      assert_no_html(html, "a[href*='aliases/new']")
    end

    # Which setup produced these values is the part that stays useful
    # once extraction has moved on.
    def test_shows_its_provenance
      html = render_page(fields: { "Collector" => "A" })

      assert_includes(html, "gemini")
      assert_includes(html, "gemini-3.6-flash")
    end

    def test_low_confidence_is_called_out
      html = render_page(fields: { "Date" => "2026-07-30" },
                         confidence: { "Date" => "low" })

      assert_includes(html, "low")
    end

    # ---------- locality ----------

    # Corrected through an autocompleter, like the ID: a table cell has
    # no room for the label one needs in order to work at all.
    def test_locality_renders_a_live_autocompleter
      html = render_page(fields: { "Location" => "Fulton, Co" })

      assert_html(html, "[data-controller='autocompleter--location']")
      assert_html(html, "#field_slip_extract_location")
    end

    # Unlike the ID, locality is an ordinary attribute write, so it
    # keeps its tick box.
    def test_locality_keeps_its_tick_box
      html = render_page(fields: { "Location" => "Fulton, Co" })

      assert_html(html, "input[name='use[Location]']")
    end

    # Typing a full MO location name back in is the slowest part of a
    # review, so an abbreviation the project already resolves is filled
    # in ready to accept -- with what the slip read shown above it.
    def test_locality_prefills_a_suggestion_from_the_projects_locations
      target = project_using(locations(:albion))

      html = render_page(fields: { "Location" => target.name[0, 6] })

      assert_html(html,
                  "input[name='value[Location]'][value='#{target.name}']")
    end

    def test_locality_keeps_what_was_written_when_nothing_matches
      html = render_page(fields: { "Location" => "Behind the barn" })

      assert_html(html,
                  "input[name='value[Location]'][value='Behind the barn']")
    end

    private

    # Puts a second observation in the project at a known location, so
    # the suggestion has something to match against.
    def project_using(location)
      @project.observations << @obs unless @project.observations.include?(@obs)
      other = observations(:detailed_unknown_obs)
      unless @project.observations.include?(other)
        @project.observations << other
      end
      other.update!(location: location)
      location
    end
  end
end
