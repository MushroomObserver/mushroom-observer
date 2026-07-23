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

  # #4884: the who line mirrors the obs show page's Collector /
  # Entered-by semantics (via Components::ObservationWho) instead of
  # the old "Who:" label. Branch coverage lives in ObservationWhoTest;
  # this pins the caption's wiring.
  def test_who_line_uses_collector_entered_by_semantics
    obs = observations(:detailed_unknown_obs)
    obs.collector = "Jane Forager"
    obs.collector_user_id = nil

    html = render_caption(obs: obs, image: nil)
    text = Nokogiri::HTML.fragment(html).at_css("#observation_who").text

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

    assert_html(html, "#observation_who a[data-controller='modal-toggle']")
  end

  def test_does_not_render_contact_link_for_own_observation
    obs = observations(:owner_accepts_general_questions)

    html = render_caption(user: obs.user, obs: obs)

    assert_no_html(html, "#observation_who [data-controller='modal-toggle']")
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

  # No vote UI in the lightbox caption (#4884). The global
  # `.vote-section` styling is an absolute bottom-pinned, opacity-0
  # thumbnail hover-overlay; inside `.lg-sub-html` it becomes an
  # invisible strip covering the caption's bottom links row and
  # swallowing clicks. Vote updates also can't sync to the caption
  # (it's a clone stored in `data-sub-html`), so the caption skips
  # the vote interface entirely.
  def test_does_not_render_vote_section
    html = render_caption

    assert_no_html(html, ".vote-section")
    assert_no_html(html, ".vote-meter")
  end

  # Regression test for the #4741/#4772 matrix-box cache-leak bug:
  # this component renders once per observation on a matrix/index
  # page (Matrix::Box -> Image::Interactive -> lightbox_caption_html),
  # not once per request, so ApplicationController's per-request
  # Textile-cache reset alone doesn't isolate sequential renders in
  # the same page load. `prepare_textile_cache` must explicitly clear
  # before registering the current observation's name.
  #
  # agaricus_campestris_obs (genus "Agaricus", letter "A") renders
  # first and registers "A" => "Agaricus" in Textile's cache.
  # boletus_edulis_obs (genus "Boletus") renders second, with notes
  # containing a bare "_A. campestris_" abbreviation it never
  # registered itself. Textile keeps the abbreviated form as the link
  # *text* either way, so the tell is the link's *href*: leaked state
  # resolves it to lookup_name/Agaricus+campestris (wrong genus);
  # correctly isolated, "A. campestris" can't resolve as a name at
  # all and falls through to a lookup_glossary_term href instead.
  def test_does_not_leak_name_lookup_across_sequential_renders
    agaricus_obs = observations(:agaricus_campestris_obs)
    boletus_obs = observations(:boletus_edulis_obs)
    boletus_obs.notes = { Other: "_A. campestris_ was not seen here" }

    render_caption(obs: agaricus_obs, image: nil)
    html = render_caption(obs: boletus_obs, image: nil)

    assert_no_html(
      html,
      "#observation_#{boletus_obs.id}_notes a[href*='lookup_name/Agaricus']",
      "Boletus caption's bare abbreviation resolved against the prior " \
      "render's leftover Agaricus registration -- Textile's " \
      "name-lookup cache leaked across sequential renders"
    )
  end

  private

  def render_caption(user: @user, image: @image, obs: @obs, **)
    render(Components::Image::Lightbox::Caption.new(
             user: user, image: image,
             image_id: (image || @image).id,
             obs: obs, **
           ))
  end
end
