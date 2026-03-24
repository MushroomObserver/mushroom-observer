# frozen_string_literal: true

require("test_helper")

class OccurrenceEditFormTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @obs1 = observations(:detailed_unknown_obs)
    @obs2 = observations(:coprinus_comatus_obs)
    @occurrence = Occurrence.create!(
      user: @user, primary_observation: @obs1
    )
    @obs1.update!(occurrence: @occurrence)
    @obs2.update!(occurrence: @occurrence)
  end

  def test_form_structure
    html = render_edit_form

    # Form tag with PATCH method
    assert_html(
      html,
      "form#occurrence_edit_form" \
      "[action='/occurrences/#{@occurrence.id}']"
    )
    assert_html(html, "input[type='hidden']" \
                      "[name='_method'][value='patch']")

    # Stimulus controller
    doc = Nokogiri::HTML(html)
    form = doc.at_css("form#occurrence_edit_form")
    assert_equal("occurrence-edit-form",
                 form["data-controller"])

    # Submit button
    assert_html(html, "input[type='submit']",
                attribute: {
                  "value" => :edit_occurrence_submit.l
                })

    # Empty hidden observation_ids[] for unchecked state
    assert_html(html, "input[type='hidden']" \
                      "[name='observation_ids[]']" \
                      "[value='']")
  end

  def test_observation_controls
    html = render_edit_form

    # Both observations have Include checkboxes (checked)
    assert_html(html,
                "input[type='checkbox']" \
                "[name='observation_ids[]']" \
                "[value='#{@obs1.id}'][checked]")
    assert_html(html,
                "input[type='checkbox']" \
                "[name='observation_ids[]']" \
                "[value='#{@obs2.id}'][checked]")

    # Primary radio: obs1 is primary (checked), obs2 is not
    assert_html(html,
                "input[type='radio']" \
                "[name='occurrence[primary_observation_id]']" \
                "[value='#{@obs1.id}'][checked]")
    doc = Nokogiri::HTML(html)
    radio2 = doc.at_css(
      "input[type='radio']" \
      "[name='occurrence[primary_observation_id]']" \
      "[value='#{@obs2.id}']"
    )
    assert(radio2, "Expected primary radio for obs2")
    assert_nil(radio2["checked"],
               "obs2 radio should not be checked")
  end

  def test_details_section
    html = render_edit_form

    # Details heading
    assert_includes(
      html, :edit_occurrence_details_heading.l
    )

    # Date input with primary obs date
    assert_html(html, "input[type='date']" \
                      "[name='primary_obs[when]']" \
                      "[id='primary_obs_when']")
  end

  def test_location_select_with_multiple_locations
    # obs1 has burbank location, give obs2 a different one
    loc2 = locations(:salt_point)
    @obs2.update!(location: loc2)
    html = render_edit_form

    # Location select appears when multiple locations
    assert_html(html, "select[name='primary_obs[location_id]']")
    assert_includes(html, :edit_occurrence_location.l)
  end

  def test_no_location_select_with_single_location
    # Both obs share same location (burbank)
    @obs2.update!(location: @obs1.location)
    html = render_edit_form

    assert_no_html(
      html, "select[name='primary_obs[location_id]']"
    )
  end

  def test_candidate_section
    candidate = observations(:amateur_obs)
    html = render_edit_form(candidates: [candidate])

    # Candidate heading
    assert_includes(
      html, :edit_occurrence_add_heading.l
    )

    # Candidate has unchecked Include checkbox
    doc = Nokogiri::HTML(html)
    cbox = doc.at_css(
      "input[type='checkbox']" \
      "[name='observation_ids[]']" \
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

  def test_no_candidate_section_when_empty
    html = render_edit_form(candidates: [])

    assert_not_includes(
      html, :edit_occurrence_add_heading.l
    )
  end

  def test_create_observation_button
    html = render_edit_form

    assert_html(
      html, "input[type='submit']" \
            "[name='create_observation']",
      attribute: {
        "value" => :edit_occurrence_create_obs.l
      }
    )
    assert_includes(
      html, :edit_occurrence_create_obs_help.l
    )
  end

  def test_field_slip_link_on_observation
    obs = observations(:minimal_unknown_obs)
    field_slip = field_slips(:field_slip_one)
    occ = Occurrence.create!(
      user: @user, primary_observation: obs,
      field_slip: field_slip
    )
    obs.update!(occurrence: occ)
    html = render_edit_form(
      occurrence: occ, observations: [obs], candidates: []
    )

    assert_includes(html, "Field Slip: #{field_slip.code}")
    assert_html(
      html, "a[href='/field_slips/#{field_slip.id}']"
    )
  end

  def test_multi_occurrence_link_on_candidate
    other = observations(:amateur_obs)
    other_occ = Occurrence.create!(
      user: @user, primary_observation: other
    )
    other.update!(occurrence: other_occ)
    # Need another obs in other_occ so observations.many? is true
    extra = observations(:agaricus_campestris_obs)
    extra.update!(occurrence: other_occ)

    html = render_edit_form(candidates: [other])

    assert_includes(html, :in_existing_occurrence.l)
    assert_html(
      html, "a[href='/occurrences/#{other_occ.id}']"
    )
  end

  def test_location_select_options_populated
    loc1 = @obs1.location
    loc2 = locations(:salt_point)
    @obs2.update!(location: loc2)
    html = render_edit_form

    doc = Nokogiri::HTML(html)
    sel = doc.at_css(
      "select[name='primary_obs[location_id]']"
    )
    assert(sel, "Expected location select element")
    opts = sel.css("option")
    assert_operator(opts.size, :>=, 2,
                    "Should have at least two location options")

    vals = opts.map { |o| o["value"].to_i }
    assert_includes(vals, loc1.id)
    assert_includes(vals, loc2.id)

    # Current primary location should be selected
    selected = sel.at_css("option[selected]")
    assert(selected, "One option should be selected")
  end

  def test_candidate_controls_unchecked
    candidate = observations(:amateur_obs)
    html = render_edit_form(candidates: [candidate])

    doc = Nokogiri::HTML(html)
    # Candidate checkbox: unchecked
    cb = doc.at_css(
      "input[type='checkbox']" \
      "[value='#{candidate.id}']"
    )
    assert(cb, "Expected candidate checkbox")
    assert_nil(cb["checked"],
               "Candidate checkbox should be unchecked")

    # Candidate radio: unchecked, has stimulus action
    radio = doc.at_css(
      "input[type='radio']" \
      "[value='#{candidate.id}']"
    )
    assert(radio, "Expected candidate primary radio")
    assert_nil(radio["checked"],
               "Candidate radio should be unchecked")
    assert_equal(
      "occurrence-edit-form#primarySelected",
      radio["data-action"]
    )
  end

  def test_obs_controls_stimulus_actions
    html = render_edit_form
    doc = Nokogiri::HTML(html)

    # Include checkbox has stimulus action
    cb = doc.at_css(
      "input[type='checkbox']" \
      "[value='#{@obs1.id}']"
    )
    assert(cb, "Expected include checkbox")
    assert_equal(
      "occurrence-edit-form#includeToggled",
      cb["data-action"]
    )

    # Primary radio has editable data attribute
    radio = doc.at_css(
      "input[type='radio']" \
      "[value='#{@obs1.id}']"
    )
    assert(radio, "Expected primary radio")
    assert(radio["data-editable"],
           "Radio should have data-editable attribute")
  end

  private

  def render_edit_form(occurrence: @occurrence,
                       observations: [@obs1, @obs2],
                       candidates: [])
    render(Components::OccurrenceEditForm.new(
             occurrence: occurrence,
             observations: observations,
             candidates: candidates,
             user: @user
           ))
  end
end
