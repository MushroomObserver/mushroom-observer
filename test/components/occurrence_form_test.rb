# frozen_string_literal: true

require("test_helper")

class OccurrenceFormTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @source = observations(:detailed_unknown_obs) # has thumb_image
    @recent = observations(:coprinus_comatus_obs) # has thumb_image
  end

  def test_form_structure
    html = render_form

    # Form tag
    assert_html(html, "form#occurrence_form[action='/occurrences']" \
                      "[method='post']")

    # Hidden fields
    assert_html(html,
                "input[type='hidden']" \
                "[name='occurrence[observation_id]']" \
                "[value='#{@source.id}']")

    # Submit button
    assert_html(html, "input[type='submit']",
                attribute: { "value" => :create_occurrence_submit.l })
  end

  def test_source_observation_box
    html = render_form

    # Source obs has hidden observation_ids[] field (always included)
    assert_html(html, "input[type='hidden']" \
                      "[name='observation_ids[]']" \
                      "[value='#{@source.id}']")

    # Source obs label
    assert_includes(html, :create_occurrence_source.l)

    # Source obs primary radio is checked
    assert_html(html, "input[type='radio']" \
                      "[name='occurrence[primary_observation_id]']" \
                      "[value='#{@source.id}'][checked]")
  end

  def test_recent_observation_box
    html = render_form

    # Recent obs has Include checkbox
    assert_html(html, "input[type='checkbox']" \
                      "[name='observation_ids[]']" \
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

  def test_thumbnail_rendered_for_obs_with_image
    html = render_form

    # Both observations have images, so thumbnails should render
    assert_html(html, ".thumbnail-container", count: 2)
  end

  def test_no_nested_forms
    html = render_form
    doc = Nokogiri::HTML(html)
    forms = doc.css("form")
    assert_equal(1, forms.size,
                 "Should have exactly one form (no nested forms)")
  end

  def test_no_thumbnail_for_obs_without_image
    # Use an observation without a thumb_image
    source = observations(:minimal_unknown_obs)
    html = render_form(source_obs: source, recent: [@recent])

    # Only one thumbnail (the recent obs)
    assert_html(html, ".thumbnail-container", count: 1)
  end

  def test_occurrence_warning_shown
    occ = Occurrence.create!(user: @user,
                             primary_observation: @recent)
    @recent.update!(occurrence: occ)

    html = render_form

    assert_includes(html, "Occurrence ##{occ.id}")
    assert_html(html, "span.text-warning")
  end

  private

  def render_form(source_obs: @source, recent: [@recent])
    render(Components::OccurrenceForm.new(
             source_obs: source_obs,
             recent_observations: recent,
             user: @user
           ))
  end
end
