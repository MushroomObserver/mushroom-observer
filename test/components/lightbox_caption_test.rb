# frozen_string_literal: true

require "test_helper"

class LightboxCaptionTest < ComponentTestCase

  def setup
    super
    @user = users(:rolf)
    @obs = observations(:coprinus_comatus_obs)
    @image = @obs.images.first
  end

  def test_renders_observation_caption_with_when_where_who
    component = Components::LightboxCaption.new(
      user: @user,
      image: @image,
      image_id: @image.id,
      obs: @obs
    )
    html = render(component)

    # Should have when/where/who sections
    assert_includes(html, "obs-when")
    assert_includes(html, "obs-where")
    assert_includes(html, "obs-who")
    assert_includes(html, "observation_when")
    assert_includes(html, "observation_where")
    assert_includes(html, "observation_who")

    # Should have image links
    assert_includes(html, "caption-image-links")
  end

  def test_renders_identify_ui_when_enabled
    component = Components::LightboxCaption.new(
      user: @user,
      image: @image,
      image_id: @image.id,
      obs: @obs,
      identify: true
    )
    html = render(component)

    # Should have identify section
    assert_includes(html, "obs-identify")
    assert_includes(html, "observation_identify_#{@obs.id}")
    # Should have "Propose a Name" button
    assert_includes(html, "Propose a Name")
  end

  def test_does_not_render_identify_ui_when_disabled
    component = Components::LightboxCaption.new(
      user: @user,
      image: @image,
      image_id: @image.id,
      obs: @obs,
      identify: false
    )
    html = render(component)

    # Should not have identify section
    assert_not_includes(html, "obs-identify")
  end

  def test_renders_image_only_caption_with_notes
    image = images(:in_situ_image)
    # Ensure image has notes
    image.update(notes: "Test image notes")

    component = Components::LightboxCaption.new(
      user: @user,
      image: image,
      image_id: image.id
    )
    html = render(component)

    # Should have image notes but not observation sections
    assert_includes(html, "image-notes")
    assert_not_includes(html, "obs-when")
    assert_not_includes(html, "obs-where")

    # Should still have image links
    assert_includes(html, "caption-image-links")
  end

  def test_renders_gps_location_when_available
    # Use observation with GPS coordinates
    obs_with_gps = observations(:minimal_unknown_obs)
    obs_with_gps.update(lat: 45.5, lng: -122.6)

    component = Components::LightboxCaption.new(
      user: @user,
      image: @image,
      image_id: @image.id,
      obs: obs_with_gps
    )
    html = render(component)

    # Should have GPS section
    assert_includes(html, "obs-where-gps")
    assert_includes(html, "observation_where_gps")
  end

  def test_always_renders_image_links
    component = Components::LightboxCaption.new(
      user: @user,
      image: @image,
      image_id: @image.id,
      obs: @obs
    )
    html = render(component)

    # Should have image links section
    assert_includes(html, "caption-image-links")
    assert_includes(html, "lightbox_link")
  end

  def test_renders_with_image_id_only
    component = Components::LightboxCaption.new(
      user: @user,
      image_id: @image.id,
      obs: @obs
    )
    html = render(component)

    # Should still render observation sections
    assert_includes(html, "obs-when")
    assert_includes(html, "obs-where")
    # Should still have image links
    assert_includes(html, "caption-image-links")
  end

  def test_renders_for_logged_out_user
    component = Components::LightboxCaption.new(
      user: nil,
      image: @image,
      image_id: @image.id,
      obs: @obs
    )
    html = render(component)

    # Should have basic structure
    assert_includes(html, "obs-when")
    assert_includes(html, "obs-where")
    assert_includes(html, "obs-who")

    # Should not have GPS section (requires logged in user)
    assert_not_includes(html, "obs-where-gps")

    # Should not have location search link (renders plain text instead)
    assert_not_includes(html, "index_observations_at_where_link")

    # Should not have user profile link (renders plain text instead)
    assert_not_includes(html, "user_link")

    # Should still have image links
    assert_includes(html, "caption-image-links")
  end
end
