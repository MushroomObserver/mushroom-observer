# frozen_string_literal: true

require "test_helper"

class ObservationFragmentLightboxTitleTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @obs = observations(:coprinus_comatus_obs)
  end

  def test_renders_basic_title_structure
    html = render_title

    assert_html(html, "#observation_what_#{@obs.id}" \
                      "[data-controller='section-update']" \
                      "[data-section-update-user-value='#{@user.id}']")

    # The observation id, styled as a badge, links to the observation.
    assert_html(html, "a#caption_obs_link_#{@obs.id}" \
                      "[href='/obs/#{@obs.id}']",
                text: @obs.id.to_s)

    # Should have the formatted name -- a bare trailing expression
    # (no `plain`/`trusted_html`) is dead code in Phlex and silently
    # renders nothing; this pins that the name text shows up.
    heading_text = Nokogiri::HTML5.fragment(html).
                   at_css("#observation_what_#{@obs.id}").text
    assert_includes(heading_text, @obs.name.text_name)
  end

  def test_renders_with_identify_mode
    html = render_title(identify: true)
    heading_text = Nokogiri::HTML5.fragment(html).
                   at_css("#observation_what_#{@obs.id}").text

    assert_includes(heading_text, :observation.ti)
  end

  def test_renders_without_identify_mode
    html = render_title(identify: false)
    heading_text = Nokogiri::HTML5.fragment(html).
                   at_css("#observation_what_#{@obs.id}").text

    assert_not_includes(heading_text, :observation.ti)
  end

  def test_renders_without_user
    html = render_title(user: nil)

    assert_html(html, "#observation_what_#{@obs.id}")
    assert_no_html(html, "[data-section-update-user-value]")
  end

  private

  def render_title(user: @user, identify: false)
    render(Components::ObservationFragment::LightboxTitle.new(
             obs: @obs,
             user: user,
             identify: identify
           ))
  end
end
