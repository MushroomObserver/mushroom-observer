# frozen_string_literal: true

require("test_helper")

module Images
  class EXIFGeocodeControllerTest < FunctionalTestCase
    include ActiveJob::TestHelper

    def test_show_renders_loading_frame_and_enqueues_job
      image = images(:in_situ_image)

      login
      assert_enqueued_with(
        job: EXIFGeocodeJob,
        args: [image.id, { read_only: false, date_differs: false }]
      ) do
        get(:show, params: { id: image.id })
      end

      assert_response(:success)
      assert_select("turbo-frame#camera_info_exif_#{image.id}")
      assert_select("turbo-frame .spinner-right")
    end

    def test_show_passes_through_read_only_and_date_differs_to_job
      image = images(:in_situ_image)

      login
      assert_enqueued_with(
        job: EXIFGeocodeJob,
        args: [image.id, { read_only: true, date_differs: true }]
      ) do
        get(:show, params: { id: image.id, read_only: "true",
                             date_differs: "true" })
      end

      assert_response(:success)
    end
  end
end
