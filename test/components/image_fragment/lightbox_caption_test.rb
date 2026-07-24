# frozen_string_literal: true

require "test_helper"

class ImageFragmentLightboxCaptionTest < ComponentTestCase
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

  # #4884: the who line mirrors the obs show page's Collector /
  # Entered-by semantics (via Components::ObservationFragment::Who)
  # instead of the old "Who:" label. Branch coverage lives in
  # ObservationFragmentWhoTest; this pins the caption's wiring.
  def test_who_line_uses_collector_entered_by_semantics
    obs = observations(:detailed_unknown_obs)
    obs.collector = "Jane Forager"
    obs.collector_user_id = nil

    html = render_caption(obs: obs, image: nil)
    text = Nokogiri::HTML.fragment(html).at_css(".obs-who").text

    assert_includes(text, :collector.ti)
    assert_includes(text, "Jane Forager")
    assert_includes(text, :entered_by.ti)
    assert_not_includes(text, "#{:who.ti}: ")
  end

  def test_renders_contact_link_when_owner_accepts_general_questions
    obs = observations(:owner_accepts_general_questions)
    viewer = users(:rolf)
    assert_not_equal(obs.user, viewer)

    html = render_caption(user: viewer, obs: obs)

    assert_html(html, ".obs-who a[data-controller='modal-toggle']")
  end

  def test_does_not_render_contact_link_for_own_observation
    obs = observations(:owner_accepts_general_questions)

    html = render_caption(user: obs.user, obs: obs)

    assert_no_html(html, ".obs-who [data-controller='modal-toggle']")
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

  # #4886: the lightbox gets its own copy of the vote UI, rendered
  # with `context: :lightbox` (see
  # Components::ImageFragment::VoteInterface) -- same dark
  # background/link treatment as `.vote-section` (the hover-overlay
  # class matrix-box/InteractiveImage thumbnails use), minus the
  # absolute positioning -- always visible, since there's no
  # `.image-sizer` ancestor here to reveal it on hover -- and every id
  # prefixed so this copy can't collide with the in-page vote section
  # once the lightbox is open and both are live in the DOM at once.
  # #4895: the vote section is a lazy-loading Turbo Frame now, not
  # rendered inline -- Matrix::Box's fragment cache has no user
  # component in its key, so rendering VoteInterface directly here
  # would bake whichever viewer wrote the cache entry's vote state
  # into the shared HTML for everyone. The frame fetches fresh, per
  # viewer, from Images::VotesController#show.
  def test_renders_lightbox_vote_section
    html = render_caption

    assert_html(html, "turbo-frame#lightbox_image_vote_#{@image.id}" \
                      "[loading='lazy']")
    assert_no_html(html, ".vote-section-lightbox")
  end

  # Anonymous viewers still get the frame shell (matches the in-page
  # vote section's own render-regardless-of-user behavior) -- per-
  # viewer hiding (`.require-user`) happens in the fetched content,
  # not at caption-render time.
  def test_renders_vote_frame_for_logged_out_user
    html = render_caption(user: nil)

    assert_html(html, "turbo-frame#lightbox_image_vote_#{@image.id}")
  end

  # No image in scope (e.g. obs-only pre-render contexts) -> no votes.
  def test_does_not_render_vote_section_without_image
    html = render_caption(image: nil)

    assert_no_html(html, "turbo-frame")
  end

  # `votes: false` propagates from the parent `BaseImage` and
  # suppresses the lightbox vote section too.
  def test_does_not_render_vote_section_when_votes_disabled
    html = render_caption(votes: false)

    assert_no_html(html, "turbo-frame")
  end

  private

  def render_caption(user: @user, image: @image, obs: @obs, **)
    render(Components::ImageFragment::LightboxCaption.new(
             user: user, image: image,
             image_id: (image || @image).id,
             obs: obs, **
           ))
  end
end
