# frozen_string_literal: true

require "test_helper"

class InfoControllerTest < FunctionalTestCase
  def test_page_loads
    get(:news)
    assert_template(:news)

    get(:show_site_stats)
    assert_template(:show_site_stats)

    get(:textile)
    assert_template(:textile_sandbox)

    get(:textile_sandbox)
    assert_template(:textile_sandbox)
  end
end
