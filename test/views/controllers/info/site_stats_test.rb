# frozen_string_literal: true

require "test_helper"

module Views::Controllers::Info
  class SiteStatsTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      controller.instance_variable_set(:@user, @user)
    end

    # Exercises both the `render_thumbs` loop (≥ 6 obs) and the
    # stats-table row rendering. The controller-level test
    # `InfoControllerTest#test_site_stats` doesn't reliably hit
    # `render_thumbs` because the fixtures rarely satisfy the
    # quality + recency + thumb-image filter the controller uses.
    def test_renders_with_observations
      observations = Observation.where.not(thumb_image_id: nil).
                     limit(6).to_a
      site_data = ::SiteData.new.get_site_data
      html = render(SiteStats.new(site_data: site_data,
                                  observations: observations))
      assert_html(html, "table.table tr td")
    end

    def test_renders_without_observations
      site_data = ::SiteData.new.get_site_data
      html = render(SiteStats.new(site_data: site_data,
                                  observations: nil))
      assert_html(html, "table.table")
    end
  end
end
