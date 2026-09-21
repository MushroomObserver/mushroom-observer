# frozen_string_literal: true

require("application_system_test_case")

# Regression coverage for the EXIF frame race fixed in #5369:
# Components::Form::CameraInfo and the lightbox EXIF modal render
# their Turbo Stream subscription directly (no turbo_frame `src=`),
# and schedule their job (EXIFGeocodeJob / EXIFDataJob) with a short
# delay so it can't broadcast before that subscription connects. The
# rest of this suite forces those jobs through with `perform_now`
# against the default :test adapter, which proves the broadcast
# content renders correctly but doesn't exercise the delay or the
# page's live Action Cable connection. This switches to :async so the
# job runs on a background thread while the browser is watching the
# page, the same way a Solid Queue worker would -- proving the
# schedule-then-broadcast mechanism delivers on its timing, not just
# that the content is correct once triggered by hand.
class ExifBroadcastTimingSystemTest < ApplicationSystemTestCase
  GEOTAGGED_LAT = "25.7582"

  def setup
    super
    @previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :async
  end

  def teardown
    ActiveJob::Base.queue_adapter = @previous_adapter
    super
  end

  def test_camera_info_exif_arrives_via_real_broadcast_delay
    obs = observations(:detailed_unknown_obs)
    image = obs.thumb_image
    image.update_column(:transferred, false)
    stage_geotagged_file(image.full_filepath("orig"))
    login!(obs.user)

    visit(edit_observation_path(obs.id))
    assert_selector("body.observations__edit")

    within("#camera_info_#{image.id}") do
      assert_selector(".spinner-right")
      assert_selector(".exif_lat", text: GEOTAGGED_LAT, wait: 10)
    end
  end

  def test_exif_modal_arrives_via_real_broadcast_delay
    obs = observations(:detailed_unknown_obs)
    image = obs.thumb_image
    stage_geotagged_file(image.full_filepath("orig"))
    login!(obs.user)

    visit("/#{obs.id}")
    assert_selector("body.observations__show")
    first(".theater-btn", visible: :all).trigger("click")
    assert_selector(".lg-sub-html")

    within(".lg-sub-html") { find("a", text: :image_show_exif.t).click }
    assert_selector("#modal_image_exif_#{image.id}", wait: 9)

    within("#modal_image_exif_#{image.id}") do
      assert_selector(".spinner-right")
      assert_selector("#exif_data_table", wait: 10)
    end
  end

  private

  def stage_geotagged_file(path)
    FileUtils.mkdir_p(File.dirname(path))
    FileUtils.cp(Rails.root.join("test/images/geotagged.jpg"), path)
  end
end
