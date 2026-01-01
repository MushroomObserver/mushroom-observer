# frozen_string_literal: true

require "test_helper"

class LightboxObservationTitleTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @obs = observations(:coprinus_comatus_obs)
  end

  def test_renders_basic_title_structure
    component = Components::LightboxObservationTitle.new(
      obs: @obs,
      user: @user
    )
    html = render(component)

    # Should have heading with proper ID and class
    assert_includes(html, "observation_what_#{@obs.id}")
    assert_includes(html, "obs-what")

    # Should have Stimulus data attributes
    assert_includes(html, 'data-controller="section-update"')
    assert_includes(html, "data-section-update-user-value=\"#{@user.id}\"")

    # Should have observation ID link
    assert_includes(html, "caption_obs_link_#{@obs.id}")
    assert_includes(html, @obs.id.to_s)
  end

  def test_renders_with_identify_mode
    component = Components::LightboxObservationTitle.new(
      obs: @obs,
      user: @user,
      identify: true
    )
    html = render(component)

    # Should have Observation label (localized)
    assert_includes(html, "Observation:")

    # Should have text-bold link style (not btn btn-primary)
    assert_includes(html, "text-bold")
    assert_not_includes(html, "btn btn-primary")
  end

  def test_renders_without_identify_mode
    component = Components::LightboxObservationTitle.new(
      obs: @obs,
      user: @user,
      identify: false
    )
    html = render(component)

    # Should not have OBSERVATION label
    assert_not_includes(html, "OBSERVATION:")

    # Should have btn btn-primary link style
    assert_includes(html, "btn btn-primary")
    assert_not_includes(html, "text-bold")
  end

  def test_renders_observation_link
    component = Components::LightboxObservationTitle.new(
      obs: @obs,
      user: @user
    )
    html = render(component)

    # Should have link to observation
    assert_includes(html, "caption_obs_link_#{@obs.id}")
    assert_includes(html, "/obs/#{@obs.id}")
    assert_includes(html, @obs.id.to_s)
  end

  def test_renders_without_user
    component = Components::LightboxObservationTitle.new(
      obs: @obs,
      user: nil
    )
    html = render(component)

    # Should still render basic structure
    assert_includes(html, "observation_what_#{@obs.id}")
    assert_includes(html, "obs-what")

    # Should not have user value in data attribute
    assert_not_includes(html, "data-section-update-user-value")
  end
end
