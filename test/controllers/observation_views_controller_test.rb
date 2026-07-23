# frozen_string_literal: true

require("test_helper")

# ------------------------------------------------------------
#  Observation views - test updating the `reviewed` column
# ------------------------------------------------------------
class ObservationViewsControllerTest < FunctionalTestCase
  def test_update_html_format
    login("mary")
    obs = Observation.needs_naming(users(:mary))
    obs_count = obs.count

    # Have to create the o_v, none existing
    obs.take(5).pluck(:id).each do |id|
      put(:update, params: { id: id, observation_view: { reviewed: "1" } })
      assert_redirected_to(identify_observations_path)
    end

    now_obs = Observation.needs_naming(users(:mary))
    now_obs_count = now_obs.count
    assert_equal(obs_count - 5, now_obs_count)
  end

  def test_update_turbo_stream_mark_as_reviewed
    login("mary")
    obs = observations(:minimal_unknown_obs)
    user = users(:mary)

    # Verify no observation_view exists yet
    assert_nil(ObservationView.find_by(observation_id: obs.id,
                                       user_id: user.id))

    put(:update,
        params: { id: obs.id, observation_view: { reviewed: "1" } },
        format: :turbo_stream)

    assert_response(:success)
    assert_equal("text/vnd.turbo-stream.html", response.media_type)

    # Verify instance variables are set correctly
    assert_equal(true, assigns(:reviewed))
    assert_equal(obs.id, assigns(:obs_id))
    assert_equal(obs, assigns(:obs))
    assert_equal(user, assigns(:user))

    # Verify observation_view was created with reviewed=true
    ov = ObservationView.find_by(observation_id: obs.id, user_id: user.id)
    assert_not_nil(ov)
    assert_equal(true, ov.reviewed)
  end

  def test_update_turbo_stream_unmark_as_reviewed
    login("mary")
    obs = observations(:minimal_unknown_obs)
    user = users(:mary)

    # Create an existing observation_view with reviewed=true
    ObservationView.create!(
      observation_id: obs.id,
      user_id: user.id,
      reviewed: true
    )

    put(:update,
        params: { id: obs.id, observation_view: { reviewed: "0" } },
        format: :turbo_stream)

    assert_response(:success)
    assert_equal("text/vnd.turbo-stream.html", response.media_type)

    # Verify instance variables are set correctly
    assert_equal(false, assigns(:reviewed))
    assert_equal(obs.id, assigns(:obs_id))
    assert_equal(obs, assigns(:obs))
    assert_equal(user, assigns(:user))

    # Verify observation_view was updated with reviewed=false
    ov = ObservationView.find_by(observation_id: obs.id, user_id: user.id)
    assert_not_nil(ov)
    assert_equal(false, ov.reviewed)
  end

  def test_update_turbo_stream_renders_caption_components
    login("mary")
    obs = observations(:minimal_unknown_obs)

    put(:update,
        params: { id: obs.id, observation_view: { reviewed: "1" } },
        format: :turbo_stream)

    assert_response(:success)

    # Verify turbo-stream actions are rendered
    assert_select("turbo-stream[action='replace']" \
                  "[target='caption_reviewed_toggle_#{obs.id}']")
    assert_select("turbo-stream[action='replace']" \
                  "[target='box_reviewed_toggle_#{obs.id}']")
    assert_select("turbo-stream[action='update_lightbox_caption']" \
                  "[obs-id='#{obs.id}']")

    # Verify the toggle checkboxes are rendered in the turbo streams
    assert_select("input[type='checkbox'][id='caption_reviewed_#{obs.id}']")
    assert_select("input[type='checkbox'][id='box_reviewed_#{obs.id}']")

    # Verify lightbox caption is rendered with the identify UI
    assert_select("div#observation_identify_#{obs.id}")
  end

  # Regression: `lightbox_caption_stream` must pass the observation's
  # thumb image through to `ImageFragment(type: :lightbox_caption,
  # ...)` -- without it, `@image` is nil inside the refreshed caption,
  # which breaks the original/EXIF links (empty `/images//original`)
  # and silently drops the vote section (gated on `@image`).
  def test_update_turbo_stream_lightbox_caption_keeps_image_and_votes
    login("mary")
    obs = observations(:coprinus_comatus_obs)
    assert_not_nil(obs.thumb_image, "fixture needs a thumb image")

    put(:update,
        params: { id: obs.id, observation_view: { reviewed: "1" } },
        format: :turbo_stream)

    assert_response(:success)
    assert_select(
      "turbo-stream[action='update_lightbox_caption'] " \
      "a[href='/images/#{obs.thumb_image.id}/original']"
    )
    assert_select(
      "turbo-stream[action='update_lightbox_caption'] " \
      ".vote-section-inline#lightbox_image_vote_#{obs.thumb_image.id}"
    )
  end
end
