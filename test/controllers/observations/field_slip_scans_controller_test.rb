# frozen_string_literal: true

require("test_helper")

module Observations
  class FieldSlipScansControllerTest < FunctionalTestCase
    def setup
      super
      @obs = observations(:minimal_unknown_obs)
      @image = images(:in_situ_image)
      @obs.images << @image unless @obs.images.include?(@image)
      @project = projects(:eol_project)
      @project.observations << @obs unless @project.observations.include?(@obs)
    end

    def test_show_requires_login
      get(:show, params: { id: @obs.id })

      assert_redirected_to(new_account_login_path)
    end

    def test_show_refused_for_an_ordinary_user
      login("katrina")

      get(:show, params: { id: @obs.id })

      assert_redirected_to(permanent_observation_path(@obs.id))
      assert_flash_error
    end

    # Every photo gets a scan button when unscanned; a photo with an
    # extract links to its review/status page instead.
    def test_show_offers_a_scan_button_per_unscanned_photo
      login("mary")

      assert(@project.is_admin?(mary), "premise: mary administers it")
      get(:show, params: { id: @obs.id })

      assert_response(:success)
      @obs.images.each do |image|
        assert_select(
          "form[action='#{image_field_slip_extract_path(image.id)}'] " \
          "button[type='submit']"
        )
      end
    end

    def test_show_links_scanned_photos_to_their_results
      FieldSlipExtract.start!(image: @image, user: mary)
      login("mary")

      get(:show, params: { id: @obs.id })

      assert_response(:success)
      assert_select(
        "a[href='#{edit_image_field_slip_extract_path(@image.id)}']"
      )
      assert_select(
        "form[action='#{image_field_slip_extract_path(@image.id)}']",
        count: 0
      )
    end

    def test_show_with_an_unknown_observation_redirects
      login("mary")

      get(:show, params: { id: -1 })

      assert_redirected_to(observations_path)
      assert_flash_error
    end
  end
end
