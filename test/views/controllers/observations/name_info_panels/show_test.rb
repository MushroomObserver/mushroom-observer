# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Observations::NameInfoPanels
  class ShowTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      @obs = observations(:coprinus_comatus_obs)
    end

    def test_wraps_content_in_the_matching_turbo_frame
      html = render(view_for(@obs))

      assert_html(html, "turbo-frame##{frame_id}")
    end

    def test_renders_on_mo_and_on_the_web_links
      html = render(view_for(@obs))

      assert_html(html, "a[href *= 'mycobank.org']")
      assert_html(html, "a[href *= 'images.google.com']")
    end

    private

    def frame_id = "name_info_frame_#{@obs.id}"

    def view_for(obs)
      Views::Controllers::Observations::NameInfoPanels::Show.new(
        obs: obs, user: @user
      )
    end
  end
end
