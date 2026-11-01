# frozen_string_literal: true

require("test_helper")

# tests of Images controller
module Images
  class EXIFControllerTest < FunctionalTestCase
    include ActiveJob::TestHelper

    def test_exif_gps_hidden
      image = images(:in_situ_image)
      image.update_attribute(:transferred, false)

      fixture = "#{MO.root}/test/images/geotagged.jpg"
      file = image.full_filepath("orig")
      path = file.sub(%r{/[^/]*$}, "")
      FileUtils.mkdir_p(path) unless File.directory?(path)
      FileUtils.cp(fixture, file)

      login
      get(:show, params: { id: image.id })
      assert_match(/latitude|longitude/i, css_select("#exif_data_table").text)

      image.observations.first.update_attribute(:gps_hidden, true)
      get(:show, params: { id: image.id })
      assert_no_match(/latitude|longitude/i,
                      css_select("#exif_data_table").text)
    end

    def test_exif_parser
      fixture = "#{MO.root}/test/images/geotagged.jpg"
      result, _status = Open3.capture2e("exiftool", fixture)
      unstripped = Image.parse_exif_data(result, false)
      assert_not_empty(unstripped.select do |key, _val|
                         key.match(/latitude|longitude|gps/i)
                       end)
      stripped = Image.parse_exif_data(result, true)
      assert_empty(stripped.select do |key, _val|
                     key.match(/latitude|longitude|gps/i)
                   end)
    end

    # turbo_stream format wraps the EXIF table in the lightbox modal,
    # loading the header itself lazily via EXIFDataJob (#5369). HTML
    # format is covered by `test_exif_gps_hidden`.
    def test_exif_show_turbo_stream
      image = images(:in_situ_image)

      login
      assert_enqueued_with(job: EXIFDataJob, args: [image.id]) do
        get(:show, params: { id: image.id }, format: :turbo_stream)
      end

      assert_response(:success)
      assert_select("#modal_image_exif_#{image.id} " \
                    "turbo-frame#exif_data_frame_#{image.id} .spinner-right")
    end

    # When exiftool exits non-zero (file missing / unreadable) the
    # controller renders the captured output with a 500 status.
    def test_exif_show_unreadable
      image = images(:in_situ_image)
      FileUtils.rm_f(image.full_filepath("orig"))

      login
      get(:show, params: { id: image.id })

      assert_response(:internal_server_error)
      assert_not_empty(response.body)
    end

    # The turbo_stream modal doesn't read EXIF at request time, so an
    # unreadable image still opens the modal with the loading spinner
    # -- EXIFDataJobTest covers the resulting `<pre>` error branch
    # once the job runs.
    def test_exif_show_turbo_stream_unreadable
      image = images(:in_situ_image)
      FileUtils.rm_f(image.full_filepath("orig"))

      login
      get(:show, params: { id: image.id }, format: :turbo_stream)

      assert_response(:success)
      assert_select("#modal_image_exif_#{image.id} " \
                    "turbo-frame#exif_data_frame_#{image.id} .spinner-right")
    end
  end
end
