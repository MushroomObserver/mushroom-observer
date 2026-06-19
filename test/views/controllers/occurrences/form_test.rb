# frozen_string_literal: true

require("test_helper")

# Unified test for Views::Controllers::Occurrences::Form — covers
# both the new-mode (model.new_record?) and edit-mode
# (model.persisted?) layouts. The two were separate `OccurrenceForm`
# and `OccurrenceEditForm` components before this consolidation.
module Views::Controllers::Occurrences
  class FormTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      @source = observations(:detailed_unknown_obs) # has thumb_image
      @recent = observations(:coprinus_comatus_obs) # has thumb_image
    end

    # ============== NEW MODE ==============
    # (model is a new Occurrence; uses source_obs + recent_observations)

    def test_new_form_structure
      html = render_new_form

      # Form tag (POST; no _method=patch override for new)
      assert_html(html, "form#occurrence_form[action='/occurrences']" \
                        "[method='post']")
      assert_no_html(html, "input[name='_method'][value='patch']")

      # Flat hidden carries the source obs id for error-redirect path.
      assert_html(html,
                  "input[type='hidden']" \
                  "[name='observation_id']" \
                  "[value='#{@source.id}']")

      # Submit button
      assert_html(html, "input[type='submit']",
                  attribute: { "value" => :create_occurrence_submit.l })
    end

    def test_new_source_observation_box
      html = render_new_form

      # Source obs has hidden observation_ids array element (always
      # included)
      assert_html(html, "input[type='hidden']" \
                        "[name='occurrence[observation_ids][]']" \
                        "[value='#{@source.id}']")

      # Source obs label
      assert_includes(html, :create_occurrence_source.l)

      # Source obs primary radio is checked
      assert_html(html, "input[type='radio']" \
                        "[name='occurrence[primary_observation_id]']" \
                        "[value='#{@source.id}'][checked]")
    end

    def test_new_recent_observation_box
      html = render_new_form

      # Recent obs has Include checkbox
      assert_html(html, "input[type='checkbox']" \
                        "[name='occurrence[observation_ids][]']" \
                        "[value='#{@recent.id}']")

      # Recent obs primary radio is not checked
      doc = Nokogiri::HTML(html)
      radio = doc.at_css(
        "input[type='radio']" \
        "[name='occurrence[primary_observation_id]']" \
        "[value='#{@recent.id}']"
      )
      assert(radio, "Expected primary radio for recent obs")
      assert_nil(radio["checked"],
                 "Recent obs radio should not be checked")

      # Primary label
      assert_includes(html, :create_occurrence_primary.l)
    end

    def test_new_matrix_ul_stimulus_wiring
      html = render_new_form
      doc = Nokogiri::HTML(html)

      # Matrix <ul> hosts the unified occurrence-form controller and
      # pins the "source" fallback strategy (revert primary to the
      # source obs when current primary's Include is unchecked).
      ul = doc.at_css("ul.row.list-unstyled")
      assert(ul, "Expected matrix <ul>")
      assert_includes(ul["data-controller"].split(/\s+/),
                      "occurrence-form")
      assert_equal("source",
                   ul["data-occurrence-form-fallback-value"])
    end

    def test_new_primary_radio_stimulus_data
      html = render_new_form
      doc = Nokogiri::HTML(html)

      # Source radio has sourceRadio target
      src_radio = doc.at_css(
        "input[type='radio']" \
        "[value='#{@source.id}']"
      )
      assert(src_radio, "Expected source primary radio")
      assert_equal("sourceRadio",
                   src_radio["data-occurrence-form-target"])

      # Recent radio has primarySelected action (no sourceRadio target)
      rec_radio = doc.at_css(
        "input[type='radio']" \
        "[value='#{@recent.id}']"
      )
      assert(rec_radio, "Expected recent primary radio")
      assert_equal("occurrence-form#primarySelected",
                   rec_radio["data-action"])
      assert_nil(rec_radio["data-occurrence-form-target"])
    end

    def test_new_thumbnail_rendered_for_obs_with_image
      html = render_new_form

      # Both observations have images, so thumbnails should render
      assert_html(html, ".thumbnail-container", count: 2)
    end

    def test_new_no_nested_superforms
      html = render_new_form
      doc = Nokogiri::HTML(html)
      superforms = doc.css("form").select do |f|
        f["id"]&.include?("occurrence")
      end
      assert_equal(1, superforms.size,
                   "Should have exactly one occurrence form")
    end

    def test_new_no_thumbnail_for_obs_without_image
      source = observations(:minimal_unknown_obs)
      html = render_new_form(source_obs: source, recent: [@recent])

      assert_html(html, ".thumbnail-container", count: 1)
    end

    def test_new_occurrence_warning_shown
      other = observations(:amateur_obs)
      occ = Occurrence.create!(user: @user,
                               primary_observation: @recent)
      @recent.update!(occurrence: occ)
      other.update!(occurrence: occ)

      html = render_new_form

      assert_includes(html, :in_existing_occurrence.l)
      assert_html(html, "a[href='/occurrences/#{occ.id}']")
    end

    def test_new_field_slip_link_shown
      obs_with_slip = observations(:minimal_unknown_obs)
      field_slip = field_slips(:field_slip_one)
      html = render_new_form(source_obs: @source,
                             recent: [obs_with_slip])

      assert_includes(html, "Field Slip: #{field_slip.code}")
      assert_html(html, "a[href='/field_slips/#{field_slip.id}']")
    end

    def test_new_recent_controls_include_checkbox_label
      html = render_new_form
      doc = Nokogiri::HTML(html)

      cb = doc.at_css(
        "input[type='checkbox']" \
        "[name='occurrence[observation_ids][]']" \
        "[value='#{@recent.id}']"
      )
      assert(cb, "Expected include checkbox for recent obs")
      assert_equal("occurrence-form#includeToggled",
                   cb["data-action"])
      label = cb.parent
      assert_equal("label", label.name)
      assert_includes(label.text, "Include")
    end

    def test_new_no_occurrence_warning_for_unlinked_obs
      plain_obs = observations(:amateur_obs)
      plain_obs.update!(occurrence: nil)
      html = render_new_form(source_obs: @source,
                             recent: [plain_obs])

      assert_not_includes(html, :in_existing_occurrence.l)
    end

    # ============== EDIT MODE ==============
    # (model is a persisted Occurrence; uses observations + candidates)

    def test_edit_form_structure
      occurrence, html = render_edit_form_for_two_obs

      # Form tag with PATCH method (Superform auto-emits)
      assert_html(html,
                  "form#occurrence_form" \
                  "[action='/occurrences/#{occurrence.id}']")
      assert_html(html, "input[type='hidden']" \
                        "[name='_method'][value='patch']")

      # Stimulus controller is on the form (spans members + candidates)
      doc = Nokogiri::HTML(html)
      form = doc.at_css("form#occurrence_form")
      assert_equal("occurrence-form", form["data-controller"])
      assert_equal("first-included",
                   form["data-occurrence-form-fallback-value"])

      # Submit button
      assert_html(html, "input[type='submit']",
                  attribute: {
                    "value" => :edit_occurrence_submit.l
                  })

      # Empty hidden observation_ids[] for unchecked state
      assert_html(html, "input[type='hidden']" \
                        "[name='occurrence[observation_ids][]']" \
                        "[value='']")
    end

    def test_edit_observation_controls
      occurrence, html = render_edit_form_for_two_obs

      # Both observations have Include checkboxes (checked)
      assert_html(html,
                  "input[type='checkbox']" \
                  "[name='occurrence[observation_ids][]']" \
                  "[value='#{@source.id}'][checked]")
      assert_html(html,
                  "input[type='checkbox']" \
                  "[name='occurrence[observation_ids][]']" \
                  "[value='#{@recent.id}'][checked]")

      # Primary radio: source obs is primary (checked)
      assert_html(html,
                  "input[type='radio']" \
                  "[name='occurrence[primary_observation_id]']" \
                  "[value='#{@source.id}'][checked]")
      doc = Nokogiri::HTML(html)
      radio2 = doc.at_css(
        "input[type='radio']" \
        "[name='occurrence[primary_observation_id]']" \
        "[value='#{@recent.id}']"
      )
      assert(radio2, "Expected primary radio for recent")
      assert_nil(radio2["checked"],
                 "Recent radio should not be checked")
      # Refute access of unused first return value
      _ = occurrence
    end

    def test_edit_details_section
      _, html = render_edit_form_for_two_obs

      assert_includes(html, :edit_occurrence_details_heading.l)

      # Date is rendered as MO's 3-select picker
      assert_html(
        html,
        "select[name='occurrence[primary_observation][when(3i)]']"
      )
      assert_html(
        html,
        "select[name='occurrence[primary_observation][when(2i)]']"
      )
      assert_html(
        html,
        "input[type='text']" \
        "[name='occurrence[primary_observation][when(1i)]']"
      )
    end

    def test_edit_location_select_with_multiple_locations
      occ = create_occurrence_for([@source, @recent])
      # Give @recent a different location than @source
      @recent.update!(location: locations(:salt_point))
      html = render_edit_form(occurrence: occ,
                              observations: [@source, @recent])

      assert_html(html,
                  "select[name='occurrence[primary_observation]" \
                  "[location_id]']")
      assert_includes(html, :edit_occurrence_location.l)
    end

    def test_edit_no_location_select_with_single_location
      occ = create_occurrence_for([@source, @recent])
      # Both obs share the same location
      @recent.update!(location: @source.location)
      html = render_edit_form(occurrence: occ,
                              observations: [@source, @recent])

      assert_no_html(
        html,
        "select[name='occurrence[primary_observation][location_id]']"
      )
    end

    def test_edit_candidate_section
      occ = create_occurrence_for([@source])
      candidate = observations(:amateur_obs)
      html = render_edit_form(occurrence: occ,
                              observations: [@source],
                              candidates: [candidate])

      assert_includes(html, :edit_occurrence_add_heading.l)

      # Candidate has unchecked Include checkbox
      doc = Nokogiri::HTML(html)
      cbox = doc.at_css(
        "input[type='checkbox']" \
        "[name='occurrence[observation_ids][]']" \
        "[value='#{candidate.id}']"
      )
      assert(cbox, "Expected checkbox for candidate")
      assert_nil(cbox["checked"],
                 "Candidate checkbox should not be checked")

      # Candidate has unchecked primary radio
      radio = doc.at_css(
        "input[type='radio']" \
        "[name='occurrence[primary_observation_id]']" \
        "[value='#{candidate.id}']"
      )
      assert(radio, "Expected primary radio for candidate")
      assert_nil(radio["checked"],
                 "Candidate radio should not be checked")
    end

    def test_edit_no_candidate_section_when_empty
      occ = create_occurrence_for([@source])
      html = render_edit_form(occurrence: occ,
                              observations: [@source],
                              candidates: [])

      assert_not_includes(html, :edit_occurrence_add_heading.l)
    end

    def test_edit_field_slip_link_on_observation
      obs = observations(:minimal_unknown_obs)
      field_slip = field_slips(:field_slip_one)
      occ = occurrences(:occ_field_slip_one)
      html = render_edit_form(occurrence: occ,
                              observations: [obs],
                              candidates: [])

      assert_includes(html, "Field Slip: #{field_slip.code}")
      assert_html(html, "a[href='/field_slips/#{field_slip.id}']")
    end

    def test_edit_multi_occurrence_link_on_candidate
      occ = create_occurrence_for([@source])
      other = observations(:amateur_obs)
      other_occ = Occurrence.create!(
        user: @user, primary_observation: other
      )
      other.update!(occurrence: other_occ)
      # Need another obs in other_occ so observations.many? is true
      extra = observations(:agaricus_campestris_obs)
      extra.update!(occurrence: other_occ)

      html = render_edit_form(occurrence: occ,
                              observations: [@source],
                              candidates: [other])

      assert_includes(html, :in_existing_occurrence.l)
      assert_html(html, "a[href='/occurrences/#{other_occ.id}']")
    end

    def test_edit_location_select_options_populated
      occ = create_occurrence_for([@source, @recent])
      loc1 = @source.location
      loc2 = locations(:salt_point)
      @recent.update!(location: loc2)
      html = render_edit_form(occurrence: occ,
                              observations: [@source, @recent])

      doc = Nokogiri::HTML(html)
      sel = doc.at_css(
        "select[name='occurrence[primary_observation][location_id]']"
      )
      assert(sel, "Expected location select element")
      opts = sel.css("option")
      assert_operator(opts.size, :>=, 2,
                      "Should have at least two location options")

      vals = opts.map { |o| o["value"].to_i }
      assert_includes(vals, loc1.id)
      assert_includes(vals, loc2.id)

      selected = sel.at_css("option[selected]")
      assert(selected, "One option should be selected")
    end

    def test_edit_candidate_controls_unchecked
      occ = create_occurrence_for([@source])
      candidate = observations(:amateur_obs)
      html = render_edit_form(occurrence: occ,
                              observations: [@source],
                              candidates: [candidate])

      doc = Nokogiri::HTML(html)
      cb = doc.at_css(
        "input[type='checkbox']" \
        "[value='#{candidate.id}']"
      )
      assert(cb, "Expected candidate checkbox")
      assert_nil(cb["checked"],
                 "Candidate checkbox should be unchecked")

      radio = doc.at_css(
        "input[type='radio']" \
        "[value='#{candidate.id}']"
      )
      assert(radio, "Expected candidate primary radio")
      assert_nil(radio["checked"],
                 "Candidate radio should be unchecked")
      assert_equal(
        "occurrence-form#primarySelected",
        radio["data-action"]
      )
    end

    def test_edit_obs_controls_stimulus_actions
      _, html = render_edit_form_for_two_obs
      doc = Nokogiri::HTML(html)

      # Include checkbox has stimulus action
      cb = doc.at_css(
        "input[type='checkbox']" \
        "[value='#{@source.id}']"
      )
      assert(cb, "Expected include checkbox")
      assert_equal("occurrence-form#includeToggled",
                   cb["data-action"])

      # Primary radio present (no sourceRadio target in edit mode)
      radio = doc.at_css(
        "input[type='radio']" \
        "[value='#{@source.id}']"
      )
      assert(radio, "Expected primary radio")
      assert_nil(radio["data-occurrence-form-target"],
                 "Edit mode should not set sourceRadio target")
    end

    private

    def render_new_form(source_obs: @source, recent: [@recent])
      render(Form.new(model: Occurrence.new(
        primary_observation: source_obs
      ),
                      source_obs: source_obs,
                      recent_observations: recent,
                      user: @user))
    end

    def render_edit_form(occurrence:, observations:, candidates: [])
      render(Form.new(model: occurrence,
                      observations: observations,
                      candidates: candidates,
                      user: @user))
    end

    def render_edit_form_for_two_obs
      occ = create_occurrence_for([@source, @recent])
      [occ, render_edit_form(occurrence: occ,
                             observations: [@source, @recent])]
    end

    def create_occurrence_for(observations)
      primary = observations.first
      occ = Occurrence.create!(user: @user, primary_observation: primary)
      observations.each { |o| o.update!(occurrence: occ) }
      occ
    end
  end
end
