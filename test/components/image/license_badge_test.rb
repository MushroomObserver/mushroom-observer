# frozen_string_literal: true

require "test_helper"

class LicenseBadgeTest < ComponentTestCase
  def test_renders_div_with_license_id
    license = licenses(:ccnc25)

    html = render(Components::Image::LicenseBadge.new(license: license))

    assert_html(html, "#license a[href='#{license.url}'][rel='license']")
  end

  def test_renders_badge_image
    license = licenses(:ccnc25)

    html = render(Components::Image::LicenseBadge.new(license: license))

    assert_html(html, "img[src='#{license.badge_url}']" \
                      "[alt='#{license.display_name}']")
  end
end
