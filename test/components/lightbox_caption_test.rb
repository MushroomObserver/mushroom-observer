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
    html = render_caption

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
    html = render_caption(identify: true)

    # Should have identify section
    assert_includes(html, "obs-identify")
    assert_includes(html, "observation_identify_#{@obs.id}")
    # Should have "Propose a Name" button
    assert_includes(html, "Propose a Name")
  end

  def test_does_not_render_identify_ui_when_disabled
    html = render_caption(identify: false)

    # Should not have identify section
    assert_not_includes(html, "obs-identify")
  end

  def test_renders_image_only_caption_with_notes
    image = images(:in_situ_image)
    image.update(notes: "Test image notes")
    html = render_caption(image: image, obs: {})

    # Should have image notes but not observation sections
    assert_includes(html, "image-notes")
    assert_not_includes(html, "obs-when")
    assert_not_includes(html, "obs-where")

    # Should still have image links
    assert_includes(html, "caption-image-links")
  end

  def test_renders_gps_location_when_available
    obs_with_gps = observations(:minimal_unknown_obs)
    obs_with_gps.update(lat: 45.5, lng: -122.6)
    html = render_caption(obs: obs_with_gps)

    # Should have GPS section
    assert_includes(html, "obs-where-gps")
    assert_includes(html, "observation_where_gps")
    # Owner can reveal → GPS link rendered
    assert_html(html, "a[href*='/observations/#{obs_with_gps.id}/map']")
  end

  # GPS hidden by the owner — the section still renders for users with
  # reveal permission, but adds the "(GPS hidden)" italic notice.
  def test_renders_gps_hidden_notice_when_owner_hides_coords
    obs = observations(:minimal_unknown_obs)
    obs.update(lat: 45.5, lng: -122.6, gps_hidden: true)
    html = render_caption(obs: obs)

    assert_includes(html, "obs-where-gps")
    assert_includes(html, :show_observation_gps_hidden.l)
  end

  # When the location's bounding box is large enough that
  # `Location#vague?` is true, a vague-location notice is rendered.
  def test_renders_vague_location_notice
    obs = observations(:minimal_unknown_obs)
    obs.update(location: locations(:burbank))
    obs.location.stub(:vague?, true) do
      html = render_caption(obs: obs)

      assert_includes(html, :show_observation_vague_location.l)
    end
  end

  # Vague-notice text is extended with an "improve" hint when the
  # current user IS the observer.
  def test_renders_vague_location_improvement_hint_for_owner
    obs = observations(:minimal_unknown_obs)
    obs.update(location: locations(:burbank))
    obs.location.stub(:vague?, true) do
      html = render_caption(user: obs.user, obs: obs)

      assert_includes(html, :show_observation_improve_location.l)
    end
  end

  # Identify mode in a controller turbo-stream context pushes an
  # ObservationView through, which renders the "mark as reviewed"
  # toggle alongside the propose-naming button.
  def test_renders_reviewed_toggle_when_observation_view_present
    obs = observations(:minimal_unknown_obs)
    obs_view = ObservationView.create!(observation: obs, user: @user)
    html = render_caption(
      obs: obs, identify: true, observation_view: obs_view
    )

    assert_includes(html, "obs-identify")
    # MarkAsReviewedToggle form lands inside the identify section.
    assert_html(html, "#observation_identify_#{obs.id} form")
  end

  # When `is_collection_location` is false, the where label says
  # "seen at" rather than "collected from".
  def test_renders_seen_at_label_for_non_collection_observations
    obs = observations(:minimal_unknown_obs)
    obs.update(is_collection_location: false)
    html = render_caption(obs: obs)

    assert_includes(html, :show_observation_seen_at.l)
  end

  def test_always_renders_image_links
    html = render_caption

    # Should have image links section
    assert_includes(html, "caption-image-links")
    assert_includes(html, "lightbox_link")
  end

  def test_renders_with_image_id_only
    html = render_caption(image: nil)

    # Should still render observation sections
    assert_includes(html, "obs-when")
    assert_includes(html, "obs-where")
    # Should still have image links
    assert_includes(html, "caption-image-links")
  end

  def test_renders_for_logged_out_user
    html = render_caption(user: nil)

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

  # The lightbox overlay is populated from this component's rendered HTML
  # (read out of the theater button's `data-sub-html`). It now embeds the
  # vote interface so users can vote without leaving the overlay —
  # matching the in-page image-show panel.
  def test_renders_vote_section_for_logged_in_user
    html = render_caption

    assert_html(html, ".vote-section#image_vote_#{@image.id}")
    assert_html(html, ".vote-meter.progress")
    assert_html(html, ".vote-buttons .image-vote-links")
  end

  # Anonymous viewers can't vote, so the section is suppressed entirely
  # (matches `images/show/_image_panel.html.erb`'s `if @user` gate).
  def test_does_not_render_vote_section_for_logged_out_user
    html = render_caption(user: nil)

    assert_no_html(html, ".vote-section")
    assert_no_html(html, ".vote-meter")
  end

  # No image in scope (e.g. obs-only pre-render contexts) → no votes.
  def test_does_not_render_vote_section_without_image
    html = render_caption(image: nil)

    assert_no_html(html, ".vote-section")
  end

  # `votes: false` propagates from the parent `BaseImage` and
  # suppresses the lightbox vote section — needed on pages that
  # don't pre-load `:image_votes` (e.g. account/profile/images
  # reuse page), otherwise `Image#users_vote(@user)` triggers a
  # Bullet N+1 inside the vote interface.
  def test_does_not_render_vote_section_when_votes_disabled
    html = render_caption(votes: false)

    assert_no_html(html, ".vote-section")
    assert_no_html(html, ".vote-meter")
  end

  private

  def render_caption(user: @user, image: @image, obs: @obs, **)
    render(Components::LightboxCaption.new(
             user: user, image: image,
             image_id: (image || @image).id,
             obs: obs, **
           ))
  end
end
